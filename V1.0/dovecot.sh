#!/bin/bash
#
#-----------------------------------------#
###Welcome to the dovecot setup script. Any variables that may need to be adjusted should be changed in the designated "variables" section in the main script. Some non variable file writes should be changed in this file if necessary though.
#-----------------------------------------#

sudo $package_manager install dovecot dovecot-pigeonhole dovecot-pgsql -y

status="$(ps ax | grep -v grep | grep dovecot)"

if [ "$status" = "" ]; then

    sudo service dovecot stop

fi

start_tag="####CURRENT BUILD !!!! LEAVE THIS TAG LINE INTACT IF YOU PLAN TO EVER USE THE SETUP SCRIPT AGAIN OR BE READY TO REINSTALL DOVECOT... DO NOT REMOVE####"
end_tag="####END OF CURRENT BUILD... YOU MAY ADJUST SETTINGS OUTSIDE OF THIS TAG, OR IF YOU WISH TO CHANGE SETTINGS IN THIS TAG, ADJUST dovecot.sh AND RERUN THE SETUP"

dovecot_conf=(protocols mail_debug)

for var in ${dovecot_conf[*]}; do
    temp="$(grep ^$var $dovecot_dir$dovecot_main)"
    if [ "$temp" != "" ]; then
        echo "Updating variable..." 
        sudo ./perl-find-replace "$temp" "$var = ${!var}" "$dovecot_dir$dovecot_main"
    else
        echo "Writing variable..."
        echo "$var = ${!var}" | sudo tee -a "$dovecot_dir$dovecot_main"
    fi
    
done

sudo sed -i "/$start_tag/,/$end_tag/d" "$dovecot_dir$dovecot_main"

echo "$start_tag

auth default {
 socket listen {
        client {
            path = /var/spool/postfix/private/auth
            mode = 0660
            user = postfix
            group = postfix
    }
        master {
            path = /var/run/dovecot/auth-master
            mode = 0600
            user = mailreader
    }
  }
}


$end_tag" | sudo tee -a "$dovecot_dir$dovecot_main"

dovecot_ssl=(ssl ssl_cert ssl_key)
file="10-ssl.conf"


for var in ${dovecot_ssl[*]}; do
    temp="$(grep ^$var $dovecot_dir$dovecot_confd$file)"
    if [ "$temp" != "" ]; then
        echo "Updating variable..." 
        sudo ./perl-find-replace "$temp" "$var = ${!var}" "$dovecot_dir$dovecot_confd$file"
    else
        echo "Writing variable..."
        echo "$var = ${!var}" | sudo tee -a "$dovecot_dir$dovecot_confd$file"
    fi
    
done

file="10-auth.conf"
dovecot_auth=(auth_mechanisms disable_plaintext_auth auth_debug_passwords)

for var in ${dovecot_auth[*]}; do
    temp="$(grep ^$var $dovecot_dir$dovecot_confd$file)"
    if [ "$temp" != "" ]; then
        echo "Updating variable..." 
        sudo ./perl-find-replace "$temp" "$var = ${!var}" "$dovecot_dir$dovecot_confd$file"
    else
        echo "Writing variable..."
        echo "$var = ${!var}" | sudo tee -a "$dovecot_dir$dovecot_confd$file"
    fi
    
done

var="!include"
temp="$(grep ^$var $dovecot_dir$dovecot_confd$file)"

if [ "$temp" != "" ]; then
     echo "Updating variable..." 
     sudo ./perl-find-replace "$temp" "$var $special_sql_file" "$dovecot_dir$dovecot_confd$file"
else
     echo "Writing variable..."
     echo "$var $special_sql_file" | sudo tee -a "$dovecot_dir$dovecot_confd$file"
fi

sudo touch $dovecot_dir$dovecot_confd$special_sql_file

sudo sed -i "/$start_tag/,/$end_tag/d" "$dovecot_dir$dovecot_confd$special_sql_file"

echo "$start_tag

passdb {
    driver = sql
    args = /etc/dovecot/dovecot-sql.conf
}
userdb {
    driver = prefetch
}
userdb {
    driver = sql
    args = /etc/dovecot/dovecot-sql.conf
}

$end_tag" | sudo tee -a "$dovecot_dir$dovecot_confd$special_sql_file"

file="10-mail.conf"
dovecot_mail=(first_valid_uid mail_uid mail_gid mail_home mail_location)

for var in ${dovecot_mail[*]}; do
    temp="$(grep ^$var $dovecot_dir$dovecot_confd$file)"
    if [ "$temp" != "" ]; then
        echo "Updating variable..." 
        sudo ./perl-find-replace "$temp" "$var = ${!var}" "$dovecot_dir$dovecot_confd$file"
    else
        echo "Writing variable..."
        echo "$var = ${!var}" | sudo tee -a "$dovecot_dir$dovecot_confd$file"
    fi
    
done

file="10-master.conf"

sudo sed -i "/$start_tag/,/$end_tag/d" "$dovecot_dir$dovecot_confd$file"

echo "$start_tag
service lmtp {
    unix_listener /var/spool/postfix/private/dovecot-lmtp {
    group = postfix
    mode = 0600
    user = postfix
    }
}

service auth {
  unix_listener auth-userdb {
    mode = 0600
    user = mailreader
    group = mail
  }
}

$end_tag" | sudo tee -a "$dovecot_dir$dovecot_confd$file"

file="15-lda.conf"

dovecot_lda=(lda_mailbox_autocreate lda_mailbox_autosubscribe)

for var in ${dovecot_lda[*]}; do
    temp="$(grep ^$var $dovecot_dir$dovecot_confd$file)"
    if [ "$temp" != "" ]; then
        echo "Updating variable..." 
        sudo ./perl-find-replace "$temp" "$var = ${!var}" "$dovecot_dir$dovecot_confd$file"
    else
        echo "Writing variable..."
        echo "$var = ${!var}" | sudo tee -a "$dovecot_dir$dovecot_confd$file"
    fi
    
done

sudo sed -i "/$start_tag/,/$end_tag/d" "$dovecot_dir$dovecot_confd$file"

echo "$start_tag

protocol lda {
    mail_plugins = \$mail_plugins sieve
    auth_socket_path = /var/run/dovecot/auth-master
    log_path = /var/log/dovecot-lda-errors.log
    info_log_path = /var/log/dovecot-lda.log
}


$end_tag" | sudo tee -a "$dovecot_dir$dovecot_confd$file"

file="20-lmtp.conf"

sudo sed -i "/$start_tag/,/$end_tag/d" "$dovecot_dir$dovecot_confd$file"

echo "$start_tag

protocol lmtp {
    mail_plugins = \$mail_plugins autocreate sieve quota
    postmaster_address = postmaster@$mydomain
    hostname = $myhostname
}

$end_tag" | sudo tee -a "$dovecot_dir$dovecot_confd$file"

file="90-plugin.conf"

sudo sed -i "/$start_tag/,/$end_tag/d" "$dovecot_dir$dovecot_confd$file"

echo "$start_tag

plugin {
    autocreate = Trash
    autocreate2 = Sent
    autocreate3 = Junk
    autosubscribe = Trash
    autosubscribe2 = Sent
    autosubscribe3 = Junk
}

$end_tag" | sudo tee -a "$dovecot_dir$dovecot_confd$file"

file="20-managesieve.conf"

sudo sed -i "/$start_tag/,/$end_tag/d" "$dovecot_dir$dovecot_confd$file"

echo "$start_tag

service managesieve-login {
  inet_listener sieve {
    port = 4190
  }
}

protocol sieve {
    managesieve_max_line_length = 65536
    managesieve_implementation_string = dovecot
    log_path = /var/log/dovecot-sieve-errors.log
    info_log_path = /var/log/dovecot-sieve.log
}

$end_tag" | sudo tee -a "$dovecot_dir$dovecot_confd$file"

file="90-sieve.conf"

sudo sed -i "/$start_tag/,/$end_tag/d" "$dovecot_dir$dovecot_confd$file"

echo "$start_tag

plugin {
    sieve = ~/.dovecot.sieve
    sieve_global_path = /etc/dovecot/sieve/default.sieve
    sieve_dir = ~/sieve
    sieve_global_dir = /etc/dovecot/sieve/global/
    sieve_max_script_size = 1M
}

$end_tag" | sudo tee -a "$dovecot_dir$dovecot_confd$file"

dovecot_sql="dovecot-sql.conf"
sudo touch "$dovecot_dir$dovecot_sql"

sudo sed -i "/$start_tag/,/$end_tag/d" "$dovecot_dir$dovecot_sql"

echo "$start_tag

driver = pgsql
connect = host=localhost dbname=$dbname user=$mailreader_user password=$database_pass
default_pass_scheme = SHA512
password_query = SELECT email as user, password FROM users WHERE email = '%u'
user_query = SELECT 200 AS uid, 12 AS gid, 'maildir:/mnt/vmail/%d/%n' FROM users WHERE email = '%u'

$end_tag" | sudo tee -a "$dovecot_dir$dovecot_sql"

sudo mkdir /etc/dovecot/sieve

sudo touch $default_sieve


sudo sed -i "/$start_tag/,/$end_tag/d" "$default_sieve"
echo "$start_tag" | sudo tee -a "$default_sieve"
echo "

#require \"vnd.dovecot.debug\";                                                   
require [\"fileinto\"];
# rule:[SPAM]                                                                   
if header :contains \"X-Spam-Flag\" \"YES\" {
  fileinto \"Junk\";
  #debug_log \"This must be spam!\";                                              
}
# rule:[SPAM2]                                                                  
#elsif header :matches \"Subject\" [\"*money*\",\"*Viagra*\",\"Cialis\"] {              
#  fileinto \"Spam\";                                                             
#}                                                                              
 else {
   #debug_log \"This isn't spam.\";                                               
 }

" | sudo tee -a "$default_sieve"
echo "$end_tag" | sudo tee -a "$default_sieve"

sudo touch /var/log/{dovecot-lda-errors.log,dovecot-lda.log}
sudo touch /var/log/{dovecot-sieve-errors.log,dovecot-sieve.log}
sudo touch /var/log/{dovecot-lmtp-errors.log,dovecot-lmtp.log}
sudo mkdir -p /etc/dovecot/sieve/global

sudo chown mailreader: -R /etc/dovecot/sieve
sudo chown mailreader:mail /var/log/dovecot-*

sudo service dovecot start
