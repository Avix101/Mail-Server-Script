#!/bin/bash
# Todo: sa-update via cron.
#-----------------------------------------#
###Welcome to the main setup script. Here you will be able to adjust crucial variables
# for each section as well as see which files executed and when.
#-----------------------------------------#
#                 _       _     _  
#/\   /\__ _ _ __(_) __ _| |__ | | ___  ___ 
#\ \ / / _` | '__| |/ _` | '_ \| |/ _ \/ __|
# \ V / (_| | |  | | (_| | |_) | |  __/\__ \
#  \_/ \__,_|_|  |_|\__,_|_.__/|_|\___||___/
#-----------------------------------------#
##Export Variables so that child processes can view them.
set -a
#-----------------------------------------#
#Postfix Settings
#-----------------------------------------#

##Required Substitutions:
virtual_mailbox_domains="example.com" #Include all domains here, format: "example.com another.com"
default_password="admin"
##
#Additional Subsitutions
mydomain="$(echo $virtual_mailbox_domains | awk '{print $1}')" #ONLY FIRST DOMAIN USED FOR HTTPS CERT
myhostname="mail.$mydomain"
myorigin="$mydomain"
inet_interfaces="all"
mydestination="localhost"
mynetworks="127.0.0.0/8"

##Additions *Possible Substitutions, be wary of direct transer
###Certificates

key_file=server.pem
cert_file=server.pem
smtpd_tls_key_file="/etc/pki/tls/private/$key_file"
smtpd_tls_cert_file="/etc/pki/tls/certs/$cert_file"

###Sasl Authentication

smtpd_recipient_restrictions="permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination"
smtpd_sasl_auth_enable=yes
broken_sasl_auth_clients=yes
smtpd_sasl_type=dovecot
smtpd_sasl_path=private/auth
smtpd_sasl_security_options=noanonymous

###Mailbox mappings, including transports and aliases

virtual_uid_maps=static:200
virtual_gid_maps=static:12
transport_maps=pgsql:/etc/postfix/pgsql/transport.cf
virtual_mailbox_base=/mnt/vmail
virtual_mailbox_maps=pgsql:/etc/postfix/pgsql/mailboxes.cf
virtual_transport=lmtp:unix:private/dovecot-lmtp
virtual_alias_maps=pgsql:/etc/postfix/pgsql/pgsql-aliases.cf
local_recipient_maps=
message_size_limit=0

###Taking Care of SPAM and VIRUSES:                                             

content_filter=smtp-amavis:[127.0.0.1]:10024

###Master.cf Configurations

#-----------------------------------------#
#Dovecot Settings
#-----------------------------------------#

##Main Conf

protocols="imap lmtp sieve"

##Main conf / Conf.d

ssl=required
ssl_cert="<$smtpd_tls_cert_file"
ssl_key="<$smtpd_tls_key_file"
first_valid_uid=200
mail_uid=200
mail_gid=12
disable_plaintext_auth=yes
auth_mechanisms="plain login"
auth_debug_passwords=yes                                                      
mail_home=/mnt/vmail/%d/%n
mail_location="maildir:~"
mail_debug=yes
lda_mailbox_autocreate=yes
lda_mailbox_autosubscribe=yes

special_sql_file="auth-sql.conf.ext.sp"


#-----------------------------------------#
#Postgresql Settings
#-----------------------------------------#
database_pass=$default_password
mailreader_user=mailreader
dbname=mail
path_to_hba="/var/lib/pgsql9/data/pg_hba.conf"
path_to_pgsql=pgsql
init_script="/etc/rc.d/init.d/postgresql"
var_store="/etc/sysconfig/pgsql/postgresql"
#PGDATA=/mnt/vmail/db
#PGLOG=/mnt/vmail/pgstartup.log

#-----------------------------------------#
#Security & Spam Settings
#-----------------------------------------#
amavis_conf="/etc/amavisd.conf"
amavis_init="/etc/init.d/amavisd"
amavis_pid="/var/amavis/amavisd.pid"
spamassassin_conf="/etc/mail/spamassassin/local.cf" 
MYHOME="/var/amavis"
undecipherable_subject_tag=""
sa_spam_subject_tag=""
#Always include spam score headers:
sa_tag_level_deflt="-9999"
#Note: Amavis ignores required_score and instead uses sa_tag2_level_deflt:
sa_tag2_level_deflt=5
required_score=5
#Disable virus scanning.  (Companies with Windows clients may want to re-enable virus scanning.  Requires more AWS resources at high volume):
#@bypass_virus_checks_maps = (1);
required_hits=5
report_safe=0
rewrite_header=""

default_sieve="/etc/dovecot/sieve/default.sieve"

#-----------------------------------------#
#Httpd ssl
#-----------------------------------------#

httpd_conf="/etc/httpd/conf/httpd.conf"
httpd_ssl_conf="/etc/httpd/conf.d/ssl.conf"
SSLCertificateFile=$smtpd_tls_cert_file
SSLCertificateKeyFile=$smtpd_tls_key_file
SSLProtocol="all -SSLv2 -SSLv3"

#-----------------------------------------#
#Squirrelmail
#-----------------------------------------#

squirrel_mail_v="1.4.22"
domain="'$mydomain';"
data_dir="'/usr/local/squirrelmail/www/data/';"
attachment_dir="'/usr/local/squirrelmail/www/attach/';"
smtpServerAddress="'localhost';"
imapServerAddress="'localhost';"


#-----------------------------------------#
#   ___  __      ___     _        _ _     
#  /___\/ _\    /   \___| |_ __ _(_) |___ 
# //  //\ \    / /\ / _ \ __/ _` | | / __|
#/ \_// _\ \  / /_//  __/ || (_| | | \__ \
#\___/  \__/ /___,' \___|\__\__,_|_|_|___/                        
#-----------------------------------------#

if [ "$(which yum)" != "" ]; then
    echo "OS uses Yum"
    package_manager="yum"
    network_file="/etc/sysconfig/network"
    postfix_dir="/etc/postfix/"
    postfix_main="main.cf"
    postfix_master="master.cf"
    dovecot_dir="/etc/dovecot/"
    dovecot_confd="conf.d/"
    dovecot_main="dovecot.conf"

elif [ "$(which apt-get)" != "" ]; then
    echo "OS uses Apt-get"
    package_manager="apt-get"

fi
#-----------------------------------------#
# __           _       _   
#/ _\ ___ _ __(_)_ __ | |_ 
#\ \ / __| '__| | '_ \| __|
#_\ \ (__| |  | | |_) | |_ 
#\__/\___|_|  |_| .__/ \__|
#               |_| 
#-----------------------------------------#
echo "Starting main setup"

sudo $package_manager update -y

sudo ./perl-find-replace "$(grep HOSTNAME $network_file)" "HOSTNAME=\"$myhostname\"" $network_file 
 
#Sub-script run order is final and should not be adjusted. In addition, subscripts should ONLY BE LAUNCHED FROM super.sh- there are many variable dependencies. Comment sub-scripts out if you don't want to run them again, but only do so after running everything at least once.

./postfix.sh

status="$(ps ax | grep -v grep | grep postfix)"

if [ "$status" = "" ]; then 
    echo "Postfix failed to start... stopping script."
    exit 1
else
    echo "Postfix up and running"
fi

#Add a mail group and mailreader user

sudo groupadd -g 12 mail
sudo useradd -g mail -u 200 -d /mnt/vmail -s /sbin/nologin mailreader

./mailx.sh

./dovecot.sh 

./pgsql.sh

./amavis.sh 

./apache.sh

./crontab.sh

if ! [ -d /usr/local/squirrelmail/www ]; then

./squirrelmail.sh

fi

sudo service dovecot restart
sudo service postfix restart

echo "

The amavisd service may fail to start the first time... this is okay. If the mail setup isn't working, just run the setup script again, and the amavisd service should start correctly. Or to start the service yourself; service amavisd start.
"

sudo service amavisd start

status="$(ps ax | grep -v grep | grep httpd)"

if [ "$status" = "" ]; then 
    echo "Starting Apache"
    sudo service httpd start
else
    echo "Restarting Apache"
    sudo service httpd restart
fi

sudo chkconfig postfix on
sudo chkconfig dovecot on
sudo chkconfig postgresql on
sudo chkconfig amavisd on
sudo chkconfig spamassassin on
sudo chkconfig httpd on

sudo chmod 700 super.sh
sudo chmod -R 600 /etc/postfix/pgsql/
sudo chmod 755 /etc/postfix/pgsql/
sudo chown -R mailreader:root /etc/postfix/pgsql/
sudo chown root:root /etc/postfix/pgsql/

echo "Script permission has been highly elevated because it contains the default plain-text password. To run super.sh again you will need to become root, or change the file's permissions. -> sudo chmod 755 super.sh" 

echo "The setup is finished!"
