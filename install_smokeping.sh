#!/bin/bash
Version_Number=`cat /etc/redhat-release | cut -f 4 -d ' '`
function Version_gt() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; }
function Version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }
read -p "Please Change The Password: " -s Root_Passwd
echo "${Root_Passwd}" | passwd root --stdin > /dev/null 2>&1
if Version_gt $Version_Number 7.6; then
    echo
    echo -e "\033[32m [INFO]: System is ok\033[0m"
    echo -e "\033[32m [INFO]: Start configuring the system environment \033[0m"
else
    echo "System is not Centos 7.6"
    exit 1;fi
if ! which wget &>/dev/null; then yum install -y wget >/dev/null 2>&1;fi
echo -e "\033[32m [Wait]: Please Wait a moment...\033[0m"
setenforce 0 >/dev/null 2>&1
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
yum -y groupinstall Development tools >/dev/null 2>&1
yum -y install expect epel* wget make gcc openssl openssl-devel rrdtool rrdtool-perl perl-core perl mod_fcgid perl-CPAN httpd httpd-devel ntpdate jq net-tools >/dev/null 2>&1
yum -y install jq >/dev/null 2>&1
yum -y install wqy-microhei-fonts.noarch >/dev/null 2>&1
ntpdate -u time3.cloud.tencent.com >/dev/null 2>&1 
if [ $? == 0 ];then
    echo -e "\033[32m [Successful]: The System Configuration success. \033[0m"
    echo -e "\033[32m [Begin]: To Begin Installing... \033[0m"
    wget https://pan.0db.org/directlink/1/dep/smokeping-ftp.sh >/dev/null  2>&1
else
    echo -e "\033[32m [ERROR]: The System Configuration Faild \033[0m"
    exit 1
fi
echo -e "\033[32m [Download]: Downloading Files...\033[0m"
File_Path=/usr/local/src/smokeping
mkdir -p ${File_Path}
wget -P ${File_Path} https://pan.0db.org/directlink/1/dep/smokeping-ftp.sh >/dev/null 2>&1
wget -P ${File_Path} https://pan.0db.org/directlink/1/dep/smokeping-2.7.3.tar.gz >/dev/null 2>&1
wget -P ${File_Path} https://pan.0db.org/directlink/1/dep/fping-4.2.tar.gz >/dev/null 2>&1
File_Number=$(ls ${File_Path} | wc -l)
if Version_ge $File_Number 3; then
    echo -e "\033[32m [Make]: Start Install Fping\033[0m"
else
    echo "\033[32m [Faild]: Download Faild"
    exit 1
fi

if [ ! -d ${File_Path}/fping-4.2 ]; then
    echo -e "\033[32m [INFO]: Fping解压缩...\033[0m"
    tar xf ${File_Path}/fping-4.2.tar.gz -C ${File_Path} >/dev/null 2>&1
    cd ${File_Path}/fping-4.2 || exit 1
    ./configure >/dev/null 2>&1 
    make -j 4 >/dev/null 2>&1 
    make install >/dev/null 2>&1
    echo -e "\033[32m [INFO]: [安装Fping] ==> OK\033[0m"
else
    echo -e "\033[32m [Faild]: 安装Fping失败,目录已存在\033[0m"
    exit 1
fi

if [ ! -d ${File_Path}/smokeping-2.7.3 ]; then
    echo -e "\033[32m [INFO]: Start Install Smokeping \033[0m"
    tar xf ${File_Path}/smokeping-2.7.3.tar.gz -C ${File_Path} >/dev/null 2>&1
    cd ${File_Path}/smokeping-2.7.3 || exit 1
    ./configure --prefix=/opt/smokeping PERL5LIB=/usr/lib64/perl5/ >/dev/null 2>&1
    /usr/bin/gmake install >/dev/null 2>&1
    echo -e "\033[32m [INFO]: [安装Smokeping] ==> OK\033[0m"
else
    echo -e "\033[32m [Faild]: 安装Smokeping失败,目录已存在\033[0m"
    exit 1
fi

echo -e "\033[32m [Configure]: Configure Smokeping... \033[0m"
echo -e "\033[32m [Wait]: Please Wait a moment...\033[0m"
if [ -d /opt/smokeping ]; then 
    cd /opt/smokeping/ || exit 1
    mkdir /opt/smokeping/htdocs/{data,cache,var} >/dev/null 2>&1
    touch /var/log/smokeping.log >/dev/null 2>&1
    cd /opt/smokeping/htdocs/ || exit 1
    mv smokeping.fcgi.dist smokeping.fcgi 
    cd /opt/smokeping/etc  || exit 1
    mv config.dist config
else 
    exit 1
fi

cat >/opt/smokeping/etc/config <<EOF
*** General ***
owner    = Peter Random
contact  = some@address.nowhere
mailhost = my.mail.host
sendmail = /sbin/sendmail
imgcache = /opt/smokeping/htdocs/cache
imgurl   = cache
datadir  = /opt/smokeping/htdocs/data
piddir  = /opt/smokeping/htdocs/var
cgiurl   = http://some.url/smokeping.cgi
smokemail = /opt/smokeping/etc/smokemail.dist
tmail = /opt/smokeping/etc/tmail.dist
# specify this to get syslog logging
syslogfacility = local0

*** Alerts ***
to = |/opt/smokeping/bin/mailx_alert.sh
from = smokealert@company.xy

+hostdown
type = loss
# in percent
pattern = ==0%,==0%,==0%,==U
comment = 对端无响应

+hightloss
type = loss
# in percent
pattern = ==0%,==0%,==0%,==0%,>10%,>10%,>10%
comment = 连续3次采样-丢包率超过10%

+lossdetect
type = loss
# in percent
pattern = ==0%,==0%,==0%,==0%,>0%,>0%,>0%
comment = 连续3次采样-存在丢包

+someloss
type = loss
# in percent
pattern = >0%,*12*,>0%,*12*,>0%
comment = 间断性丢包

+rttdetect
type = rtt
# in milli seconds
pattern = <100,<100,<100,<100,<100,<150,>150,>150,>150
comment = 连续3次采样延迟增大-超过150ms

*** Database ***
step     = 60
pings    = 20

# consfn mrhb steps total

AVERAGE  0.5   1  1008
AVERAGE  0.5  12  4320
    MIN  0.5  12  4320
    MAX  0.5  12  4320
AVERAGE  0.5 144   720
    MAX  0.5 144   720
    MIN  0.5 144   720

*** Presentation ***

template = /opt/smokeping/etc/basepage.html.dist
htmltitle = yes
graphborders = no

#+ charts
#menu = Charts
#title = The most interesting destinations

#++ stddev
#sorter = StdDev(entries=>4)
#title = Top Standard Deviation
#menu = Std Deviation
#format = Standard Deviation %f

#++ max
#sorter = Max(entries=>5)
#title = Top Max Roundtrip Time
#menu = by Max
#format = Max Roundtrip Time %f seconds

#++ loss
#sorter = Loss(entries=>5)
#title = Top Packet Loss
#menu = Loss
#format = Packets Lost %f

#++ median
#sorter = Median(entries=>5)
#title = Top Median Roundtrip Time
#menu = by Median
#format = Median RTT %f seconds

+ overview
width = 600
height = 50
range = 10h

+ detail
width = 600
height = 200
unison_tolerance = 2

"Last 3 Hours"    3h
"Last 30 Hours"   30h
"Last 10 Days"    10d
"Last 400 Days"   400d

*** Probes ***
+ FPing
binary = /usr/local/sbin/fping
#可以设置源IP地址，适用于多IP的服务器，（比如组专线内网+公网）服务器
#sourceaddressn = 1.1.1.1

*** Slaves ***
secrets=/opt/smokeping/etc/smokeping_secrets.dist
+aliyun
display_name=阿里印度孟买slave
location=India
color=ff0000

*** Targets ***
probe = FPing

menu = Top
title = 网络质量监控系统
remark = 如果您是合法管理员，那么欢迎您，如果不是，请立即离开 \
         Only legal administrators are welcome, if you are not, please leave immediately

#加载额外的监控主机（将监控主机，单独成一个文件）
#@include targets
EOF

echo -e "\033[32m [Wait]: Please Wait a moment...\033[0m"
touch /etc/httpd/conf.d/vhost.conf >/dev/null 2>&1

cat > /etc/httpd/conf.d/vhost.conf << EOF
DocumentRoot /opt/smokeping
<directory /opt/smokeping/htdocs>
AllowOverride None
Options All
AddHandler cgi-script .fcgi .cgi
AllowOverride AuthConfig
Order allow,deny
#Require all granted
#指定不用权限认证的salve节点
#Require ip 113.2.2.2
Allow from all
AuthName "Smokeping"
AuthType Basic
AuthUserFile /opt/smokeping/htdocs/htpasswd
Require valid-user
DirectoryIndex smokeping.fcgi
</directory>
EOF
read -p "Please Enter Web_Name: " Web_Name
read -p "Please Enter Web_Passwd: " -s Web_Passwd
chown apache. /opt/smokeping/htdocs/{data,cache,var} -R
chown apache. /var/log/smokeping.log
chmod 600 /opt/smokeping/etc/smokeping_secrets.dist
htpasswd -bc /opt/smokeping/htdocs/htpasswd ${Web_Name} ${Web_Passwd}

Web_IP=$(ifconfig |grep inet|grep -v '127.0.0.1'| grep -v inet6 | awk '{print $2}'|paste -d "," -s)
systemctl start httpd >/dev/null 2>&1 
systemctl enable httpd >/dev/null 2>&1

/opt/smokeping/bin/smokeping --logfile=/var/log/smokeping.log >/dev/null 2>&1
echo "/opt/smokeping/bin/smokeping --logfile=/var/log/smokeping.log 2>&1 &" >> /etc/rc.local 
chmod +x /etc/rc.d/rc.local
Date_Time=$(date +%Y-%m-%d-%H:%M)
Isp=$(curl -s https://api-ipv4.ip.sb/geoip|jq -r .isp|awk '{print $1,$2}')
Open_IP=$(curl -s https://api-ipv4.ip.sb/geoip|jq -r .ip)
Service_Status=$(systemctl status firewalld | grep running | wc -l)
if [ ${Service_Status} -eq 0 ]; then
    systemctl start firewalld >/dev/null 2>&1
    systemctl enable firewalld >/dev/null 2>&1
    firewall-cmd --add-port=80/tcp --permanent >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1
    systemctl restart httpd >/dev/null 2>&1
else
    firewall-cmd --add-port=80/tcp --permanent >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1
    systemctl restart httpd >/dev/null 2>&1
fi
Httpd_Status=$(systemctl status httpd | grep running | wc -l)
echo -e "\033[32m [Sucessful]: Smokeping Deployment Successful \n [具体配置信息如下]:\033[0m"

if [ ${Web_IP} == ${Open_IP} ];then
    echo -e "\033[32m [系统]：Centos ${Version_Number} \n [公网IP]: ${Open_IP} \n [运营商]: ${Isp} \n [账号]：root \n [密码]：${Root_Passwd} \n [访问地址]: http://${Open_IP}/htdocs \n [二次验证]：${Web_Name}/${Web_Passwd} \n [当前时间]：${Date_Time}\033[0m"
else
    echo -e "\033[32m [系统]：Centos ${Version_Number} \n [内网IP]: ${Web_IP} \n [公网IP]: ${Open_IP} \n [运营商]: ${Isp} \n [账号]：root \n [密码]：${Root_Passwd} \n [访问地址]: http://${Open_IP}/htdocs \n [二次验证]：${Web_Name}/${Web_Passwd} \n [当前时间]：${Date_Time}\033[0m"
fi

if [ $? -eq 0 ];then
	wget -P /root/ https://pan.0db.org/directlink/1/dep/cfg_smokeping.sh >/dev/null 2>&1
	read -r -p $'\033[32m [INFO] 是否现在配置配置文件呢？[Y/N]' MESSAGE
	    case ${MESSAGE} in
			Y|y)
			sh /root/cfg_smokeping.sh
			;;
			N|n)
			echo -e "\033[32m [INFO] 您选择稍后执行sh ./cfg_smokeping命令\033[0m"
			;;
			*)
		esac
fi
if [ $? -eq 0 ];then
	echo -e "\033[32m [INFO] 准备下载FTP文件，请稍后\n [INFO] 需要先删除原来的配置文件\033[0m"
	sh ${File_Path}/smokeping-ftp.sh
fi
if [ ${Httpd_Status} -eq 0 ]; then
    echo -e "\033[32m [Fail]: http://${Open_IP}无法访问,Please Check The Httpd Service Configuration\033[0m"
    exit 1
else
    echo
fi