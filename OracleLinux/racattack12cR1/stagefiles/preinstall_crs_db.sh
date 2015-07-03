#!/bin/bash
#take care of some prerequirements

#stop sendmail service if we are in a container
if [ -c /dev/lxc/console ]; then
  [ -f /etc/init.d/sendmail ] && chkconfig sendmail off
fi

#set required ulimit for grid user
if [ -f /etc/security/limits.conf.preinstall ]; then
  echo "seems this part was already executed"
else
  cp /etc/security/limits.conf /etc/security/limits.conf.preinstall
    if [ -c /dev/lxc/console ]; then
      echo 'grid  soft  nproc  2047'>> /etc/security/limits.conf
	  echo 'oracle  soft  nproc  2047'>> /etc/security/limits.conf
      mv /etc/security/limits.d/oracle-rdbms-server-12cR1-preinstall.conf /etc/security/limits.d/oracle-rdbms-server-12cR1-preinstall.conf.ori
      grep -v nofile /etc/security/limits.d/oracle-rdbms-server-12cR1-preinstall.conf.ori > /etc/security/limits.d/oracle-rdbms-server-12cR1-preinstall.conf
    else
      echo 'grid  hard  nofile  65536'>> /etc/security/limits.conf
      echo 'grid  soft  nproc  2047'>> /etc/security/limits.conf
	  echo 'oracle  hard  nofile  65536'>> /etc/security/limits.conf
      echo 'oracle  soft  nproc  2047'>> /etc/security/limits.conf
    fi
fi

#set pam login
sed -i -e '/session    required     pam_selinux.so open/i\
session    required     \/lib64\/security\/pam_limits.so\
session    required     pam_limits.so' /etc/pam.d/login

#set initial password
echo oracle | passwd --stdin oracle
echo grid   | passwd --stdin grid

#create and set owner/permissions on path structure

if [ -d /u01 ]; then
  mkdir -p /u01/stage
  cd /u01/stage
  if [ $? -ne 0 ];then
     echo "can't change into /u01/stage. Please review and run this script again"
     exit 1
  fi
else
  echo " /u01 mount point doesn't exist. Please create and run this script again "
  exit 1
fi

cp /etc/sudoers /etc/sudoers.ori
sed -i -e 's/^Defaults\s*requiretty$/#Defaults\trequiretty/' /etc/sudoers
grep '^%oinstall' /etc/sudoers || echo '%oinstall        ALL=(ALL)       NOPASSWD: ALL' >> /etc/sudoers

cp /etc/fstab /etc/fstab.ori

#per Oracle manual, we require add rw,exec to /dev/shm
#and will adjust size to 90% of ram

egrep -v '/dev/shm' /etc/fstab.ori > /etc/fstab
awk '{ $1="MemTotal:" };END{printf "tmpfs  /dev/shm  tmpfs  rw,exec,size=%.0fm,defaults  0 0\n", $2/1024*0.9}' /proc/meminfo >> /etc/fstab 

mountpoint /dev/shm 2>&1 >/dev/null  && mount -o remount,rw,exec /dev/shm || mount /dev/shm

cp /etc/sysctl.conf /etc/sysctl.conf.ori

egrep -v "net.bridge.bridge-nf-call" /etc/sysctl.conf.ori > /etc/sysctl.conf

[ $1 ] && ARG=$1 || ARG="empty"

if [ $ARG == "rac" ] ;then
  ifconfig eth2 2>/dev/null >/dev/null
  if [ $? -eq 0 ];then
    RP_ETH2="net.ipv4.conf.eth2.rp_filter=2"
    grep $RP_ETH2 /etc/sysctl.conf 2>/dev/null || echo $RP_ETH2 >> /etc/sysctl.conf
  fi
  ifconfig eth3 2>/dev/null >/dev/null
  if [ $? -eq 0 ];then
    RP_ETH3="net.ipv4.conf.eth3.rp_filter=2"
    grep $RP_ETH3 /etc/sysctl.conf 2>/dev/null || echo $RP_ETH3 >> /etc/sysctl.conf
  fi
fi

sysctl -p

mkdir -p /u01/app/grid /u01/app/oraInventory /u01/app/grid/12.1.0.2 /u01/app/oracle/product/12.1.0.2/dbhome_1
chown       oracle:oinstall     /u01
chown -R    oracle:oinstall     /u01/app
chown -R    oracle:oinstall     /u01/stage
chown -R    grid:oinstall       /u01/app/grid
chown -R    grid:oinstall       /u01/app/oraInventory
chown -R    oracle:oinstall     /home/oracle
chown -R    grid:oinstall       /home/grid
chmod -R    ug+rw               /u01

# final command must return success or vagrant thinks the script failed
echo "successfully completed preinstall steps"