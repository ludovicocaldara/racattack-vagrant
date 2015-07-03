# I need to change and include the following parameters:
# 1. cl_prefix
# 2. cl_domain (instead of racattack)
# 3. public_lan
# 4. private_lan
# 5. hub count
# 6. hub starting count (51)
# 7. vip starting count (61)
# 8. leaf count
# 9. leaf starting count (81)
# 10. app count
# 12. scan count
# 11. app starting count (101)
# 13. scan starting count (251)

if [ $# -ne 13 ] ; then
	cat - <<EOF
	Usage: $0    <with 13 parameters:>
	# 1. cl_prefix
	# 2. cl_domain (instead of racattack)
	# 3. public_lan
	# 4. private_lan
	# 5. hub count
	# 6. hub starting count (51)
	# 7. vip starting count (61)
	# 8. leaf count
	# 9. leaf starting count (81)
	# 10. app count
	# 11. app starting count (101)
	# 12. scan count
	# 13. scan starting count (251)
EOF
	exit 1
fi

cl_prefix=$1
cl_domain=$2
public_lan=$3
private_lan=$4
hub_count=$5
hub_starting_count=$6
vip_starting_count=$7
leaf_count=$8
leaf_starting_count=$9
app_count=$10
app_starting_count=$11
scan_count=$12
scan_starting_count=$13

base_public=`echo $public_lan | awk -F. '{printf ("%d.%d.%d.",$1,$2,$3) }'`
base_private=`echo $private_lan | awk -F. '{printf ("%d.%d.%d.",$1,$2,$3) }'`
slave_ip="${base_public}$(($hub_starting_count+1))"
master_ip="${base_public}${hub_starting_count}"

if [ -f /var/named/${cl_domain} ];then
  echo "named already configured in $HOSTNAME"
  exit 0
fi 

chkconfig named on
service named stop
rm -f /var/named/${cl_domain} /var/named/in-addr.arpa

touch /var/named/${cl_domain}
chmod 664 /var/named/${cl_domain}
chgrp named /var/named/${cl_domain}
chmod g+w /var/named
chmod g+w /var/named/${cl_domain}

cp /etc/named.conf /etc/named.conf.ori


#grep '192.168.78.52' /etc/named.conf && echo "already configured " || sed -i -e 's/listen-on .*/listen-on port 53 { 192.168.78.52; 127.0.0.1; };/' \
#-e 's/allow-query .*/allow-query     { 192.168.78.0\/24; localhost; };/' -e 's/type master;/type slave;\n masters  {192.168.78.51; };/' \
#-e '$azone "racattack" {\n  type slave;\n  masters  { 192.168.78.51; };\n  file "racattack";\n};\n\n zone "in-addr.arpa" {\n  type slave;\n  masters  { 192.168.78.51; };\n  file "in-addr.arpa";\n};' \
#/etc/named.conf

### CREATING THE NEW named.conf
cat <<EOF > /etc/named.conf
options {
       listen-on port 53 { $slave_ip; };
       listen-on-v6 port 53 { ::1; };
       directory       "/var/named";
       dump-file       "/var/named/data/cache_dump.db";
       statistics-file "/var/named/data/named_stats.txt";
       memstatistics-file "/var/named/data/named_mem_stats.txt";
       allow-query     { $public_lan/24; localhost; };
       allow-transfer  { $public_lan/24; };
       recursion yes;

       dnssec-enable yes;
       dnssec-validation yes;
       dnssec-lookaside auto;

       /* Path to ISC DLV key */
       bindkeys-file "/etc/named.iscdlv.key";

       managed-keys-directory "/var/named/dynamic";
};

logging {
       channel default_debug {
               file "data/named.run";
               severity dynamic;
       };
};

zone "." IN {
       type hint;
       file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";

zone "$cl_domain" {
 type slave;
 masters  { ${master_ip}; };
 file "$cl_domain";
};

zone "in-addr.arpa" {
 type slave;
 masters  { ${master_ip}; };
 file "in-addr.arpa";
};
EOF


if [ ! -f /etc/rndc.key ] ; then
  rndc-confgen -a -r /dev/urandom
  chgrp named /etc/rndc.key
  chmod g+r /etc/rndc.key
  service named restart
else
  service named restart
fi

# final command must return success or vagrant thinks the script failed
echo "successfully completed named steps"
