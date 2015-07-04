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

echo $#
echo $@

cl_prefix=$1
cl_domain=$2
public_lan=$3
private_lan=$4
hub_count=$5
hub_starting_count=$6
vip_starting_count=$7
leaf_count=$8
leaf_starting_count=$9
app_count=${10}
app_starting_count=${11}
scan_count=${12}
scan_starting_count=${13}

if [ $hub_count -lt 2 ] ; then
	hub_count=2
fi

# if [ -f /var/named/${cl_domain} ];then
#  echo "named already configured in $HOSTNAME"
#  exit 0
#fi

chkconfig named on
touch /var/named/${cl_domain}
chmod 664 /var/named/${cl_domain}
chgrp named /var/named/${cl_domain}
chmod g+w /var/named
chmod g+w /var/named/${cl_domain}

cp /etc/named.conf /etc/named.conf.ori

base_public=`echo $public_lan | awk -F. '{printf ("%d.%d.%d.",$1,$2,$3) }'`
base_private=`echo $private_lan | awk -F. '{printf ("%d.%d.%d.",$1,$2,$3) }'`
master_ip="${base_public}${hub_starting_count}"

#grep $master_ip /etc/named.conf && echo "already configured " || sed -i -e 's/listen-on .*/listen-on port 53 { 192.168.78.51; 127.0.0.1; };/' \
#-e 's/allow-query .*/allow-query     { 192.168.78.0\/24; localhost; };\n        allow-transfer  { 192.168.78.0\/24; };/' \
#-e '$azone "racattack" {\n  type master;\n  file "racattack";\n};\n\nzone "in-addr.arpa" {\n  type master;\n  file "in-addr.arpa";\n};' \
#/etc/named.conf


### CREATING THE NEW named.conf
cat <<EOF > /etc/named.conf
options {
       listen-on port 53 { $master_ip; };
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
 type master;
 file "$cl_domain";
};

zone "in-addr.arpa" {
 type master;
 file "in-addr.arpa";
};
EOF


### CREATING THE NEW dns domain file
echo '$ORIGIN .
$TTL 10800      ; 3 hours' > /var/named/$cl_domain

echo "$cl_domain               IN SOA  ${cl_prefix}h01.$cl_domain. hostmaster.$cl_domain. (
                                101        ; serial
                                86400      ; refresh (1 day)
                                3600       ; retry (1 hour)
                                604800     ; expire (1 week)
                                10800      ; minimum (3 hours)
                                )
                        NS      ${cl_prefix}h01.$cl_domain.
                        NS      ${cl_prefix}h02.$cl_domain." >> /var/named/$cl_domain
echo '$ORIGIN '$cl_domain'.' >>  /var/named/$cl_domain

## adding scan IPs
echo "${cl_prefix}-scan    A       ${base_public}${scan_starting_count}" >> /var/named/$cl_domain
i=1
while [ $i -lt $scan_count ] ; do
	echo "    A       ${base_public}$(($scan_starting_count+$i))" >> /var/named/$cl_domain
	i=$(($i+1))
done

## adding public HUB IPs
i=0
while [ $i -lt $hub_count ] ; do
	echo "${cl_prefix}h`printf "%02d" $(($i+1))`     A       ${base_public}$(($hub_starting_count+$i))" >> /var/named/$cl_domain
	i=$(($i+1))
done
## adding  HUB PRIV IPs
i=0
while [ $i -lt $hub_count ] ; do
	echo "${cl_prefix}h`printf "%02d" $(($i+1))`-priv     A       ${base_private}$(($hub_starting_count+$i))" >> /var/named/$cl_domain
	i=$(($i+1))
done
## adding public HUB VIP IPs
i=0
while [ $i -lt $hub_count ] ; do
	echo "${cl_prefix}h`printf "%02d" $(($i+1))`-vip     A       ${base_public}$(($vip_starting_count+$i))" >> /var/named/$cl_domain
	i=$(($i+1))
done

## adding public LEAF IPs
i=0
while [ $i -lt $leaf_count ] ; do
	echo "${cl_prefix}l`printf "%02d" $(($i+1))`     A       ${base_public}$(($leaf_starting_count+$i))" >> /var/named/$cl_domain
	i=$(($i+1))
done
## adding  LEAF PRIV IPs
i=0
while [ $i -lt $leaf_count ] ; do
	echo "${cl_prefix}l`printf "%02d" $(($i+1))`-priv     A       ${base_private}$(($leaf_starting_count+$i))" >> /var/named/$cl_domain
	i=$(($i+1))
done

## adding public APP IPs
i=0
while [ $i -lt $app_count ] ; do
	echo "${cl_prefix}a`printf "%02d" $(($i+1))`     A       ${base_public}$(($app_starting_count+$i))" >> /var/named/$cl_domain
	i=$(($i+1))
done

echo "localhost               A       127.0.0.1" >> /var/named/$cl_domain
echo '$ORIGIN '${cl_prefix}'.'${cl_domain}'.' >> /var/named/$cl_domain

echo "@                       NS      ${cl_prefix}-gns.${cl_prefix}.${cl_domain}." >> /var/named/$cl_domain
echo "${cl_prefix}-gns     A       ${base_public}244" >> /var/named/$cl_domain



##### CREATING THE NEW REVERSE-LOOKUP FILE
echo '$ORIGIN .
$TTL 10800      ; 3 hours' > /var/named/in-addr.arpa

echo "in-addr.arpa            IN SOA  ${cl_prefix}h01.${cl_domain}. hostmaster.${cl_domain}. (
                                101        ; serial
                                86400      ; refresh (1 day)
                                3600       ; retry (1 hour)
                                604800     ; expire (1 week)
                                10800      ; minimum (3 hours)
                                )
                        NS      ${cl_prefix}h01.${cl_domain}.
                        NS      ${cl_prefix}h02.${cl_domain}." >> /var/named/in-addr.arpa

base_public_reverse=`echo $public_lan | awk -F. '{printf ("%d.%d.%d.",$3,$2,$1) }'`
base_private_reverse=`echo $private_lan | awk -F. '{printf ("%d.%d.%d.",$3,$2,$1) }'`
						
echo '$ORIGIN '${base_private_reverse}"in-addr.arpa." >> /var/named/in-addr.arpa
## adding  HUB PRIV IPs
i=0
while [ $i -lt $hub_count ] ; do
	echo "$(($hub_starting_count+$i))			PTR		${cl_prefix}h`printf "%02d" $(($i+1))`-priv.${cl_prefix}." >> /var/named/in-addr.arpa
	i=$(($i+1))
done
## adding LEAF PRIV IPs
i=0
while [ $i -lt $leaf_count ] ; do
	echo "$(($leaf_starting_count+$i))			PTR		${cl_prefix}l`printf "%02d" $(($i+1))`-priv.${cl_prefix}." >> /var/named/in-addr.arpa
	i=$(($i+1))
done
echo '$ORIGIN '${base_public_reverse}"in-addr.arpa." >> /var/named/in-addr.arpa

## adding  SCAN IPs
i=0
while [ $i -lt $scan_count ] ; do
	echo "$(($scan_starting_count+$i))			PTR		${cl_prefix}-scan.${cl_prefix}." >>/var/named/in-addr.arpa
	i=$(($i+1))
done
## adding  HUB PUBLIC IPs
i=0
while [ $i -lt $hub_count ] ; do
	echo "$(($hub_starting_count+$i))			PTR		${cl_prefix}h`printf "%02d" $(($i+1))`.${cl_prefix}." >> /var/named/in-addr.arpa
	i=$(($i+1))
done
## adding  HUB PUBLIC VIPs
i=0
while [ $i -lt $hub_count ] ; do
	echo "$(($vip_starting_count+$i))			PTR		${cl_prefix}h`printf "%02d" $(($i+1))`-vip.${cl_prefix}." >> /var/named/in-addr.arpa
	i=$(($i+1))
done
## adding  LEAF PUBLIC IPs
i=0
while [ $i -lt $leaf_count ] ; do
	echo "$(($leaf_starting_count+$i))			PTR		${cl_prefix}l`printf "%02d" $(($i+1))`.${cl_prefix}." >> /var/named/in-addr.arpa
	i=$(($i+1))
done
## adding  APP PUBLIC IPs
i=0
while [ $i -lt $app_count ] ; do
	echo "$(($app_starting_count+$i))			PTR		${cl_prefix}a"`printf "%02d" $(($i+1))`".${cl_prefix}." >> /var/named/in-addr.arpa
	i=$(($i+1))
done

echo "244			PTR	${cl_prefix}-gns.${cl_prefix}.${cl_domain}." >> /var/named/in-addr.arpa



if [ ! -f /etc/rndc.key ] ; then
  rndc-confgen -a -r /dev/urandom
  chgrp named /etc/rndc.key
  chmod g+r /etc/rndc.key
fi
  service named restart || true

# final command must return success or vagrant thinks the script failed
echo "successfully completed named steps"
