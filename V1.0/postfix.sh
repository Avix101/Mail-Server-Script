#!/bin/bash
#
#-----------------------------------------#
###Welcome to the Postfix Setup File
#Most Postfix related configurations will be found here,
#including settings that may be related to other components in the mail server
#setup. Some postfix items may be excluded until later in the setup process
#for various reasons. 

echo "Welcome to the Postfix configuration section!"

echo "If you want / need to adjust installation parameters, open the 'super.sh' bash script and adjust the variables in the 'Variables' section near the top. Items will be clearly labeled and explained if necessary."

#Approaching the postfix installation and configuration section.

#Check and uninstall sendmail 
    
echo "Checking for sendmail installation..."

if [ "$(rpm -q sendmail)" != "package sendmail is not installed" ]
then
    echo "sendmail is installed, removing now."
    sudo $package_manager remove sendmail -y

else
    echo "sendmail is not installed, continue."

fi

#Check and install postfix                                                      
echo "Checking for postfix installation..."

if [ "$(rpm -q postfix)" == "package postfix is not installed" ]
then
    echo "postfix is not intalled, installing now"
    sudo $package_manager install postfix -y

else
    echo "postfix is installed, continue."

fi

#Stop Postfix if it is runing

status="$(ps ax | grep -v grep | grep postfix)"

if ! [ "$status" = "" ]; then

   sudo postfix stop

fi

#Checking postfix installation

if [ -d "$postfix_dir" ]
then
    echo "All good so far."
else
    echo "Fatal Error: postfix directory not present"
    exit

fi

sudo yum install cyrus-sasl-plain -y

status="$(ps ax | grep -v grep | grep saslauthd)"

if [ "$status" = "" ]; then

    sudo service saslauthd start

else

    sudo service saslauthd restart

fi

#Correct all of the postfix settings by adjusting existing settings and writing in new ones
postfix_settings=(mydomain myhostname myorigin inet_interfaces mydestination mynetworks smtpd_tls_key_file smtpd_tls_cert_file smtpd_recipient_restrictions smtpd_sasl_auth_enable broken_sasl_auth_clients smtpd_sasl_type smtpd_sasl_path smtpd_sasl_security_options virtual_uid_maps virtual_gid_maps transport_maps virtual_mailbox_base virtual_mailbox_maps virtual_transport virtual_mailbox_domains virtual_alias_maps local_recipient_maps message_size_limit content_filter)

for var in ${postfix_settings[*]}; do
    temp="$(grep ^$var $postfix_dir$postfix_main)"
    if [ "$temp" != "" ]; then
        echo "Updating variable..." 
        sudo ./perl-find-replace "$temp" "$var = ${!var}" "$postfix_dir$postfix_main"
    else
        echo "Writing variable..."
        echo "$var = ${!var}" | sudo tee -a "$postfix_dir$postfix_main"
    fi
    
done

#Check the current state of master.cf

temp="$(grep -m 1 ^"smtp" /etc/postfix/master.cf |cut -f1 -d:)"
temp_num="$(grep -n -m 1 ^"smtp" /etc/postfix/master.cf |cut -f1 -d:)"

if [ "$temp_num" -lt "20" ]; then
    echo "Removing default line."
    sudo ./perl-find-replace "$temp" "#$temp" "$postfix_dir$postfix_master"
else
    echo "Current config checks out, moving on."
fi

#These tags essentially contain all of the settings that the setup script will write. Everytime the setup script runs, the items within the tags will be erased and rewritten according to the specifications in this file. Settings changed outside of the tags will not be altered.

start_tag="####CURRENT BUILD !!!! LEAVE THIS TAG LINE INTACT IF YOU PLAN TO EVER USE THE SETUP SCRIPT AGAIN OR BE READY TO REINSTALL POSTFIX... DO NOT REMOVE####"
end_tag="####END OF CURRENT BUILD... YOU MAY ADJUST SETTINGS OUTSIDE OF THIS TAG, OR IF YOU WISH TO CHANGE SETTINGS IN THIS TAG, ADJUST postfix.sh AND RERUN THE SETUP"

sudo sed -i "/$start_tag/,/$end_tag/d" "$postfix_dir$postfix_master"

echo "Building current config..."
echo "####CURRENT BUILD !!!! LEAVE THIS TAG LINE INTACT IF YOU PLAN TO EVER USE THE SETUP SCRIPT AGAIN OR BE READY TO REINSTALL POSTFIX... DO NOT REMOVE####" | sudo tee -a "$postfix_dir$postfix_master"  
echo "" | sudo tee -a "$postfix_dir$postfix_master"

#Postfix Master.cf Current Build. If you wish to adjust any of these settings, do so here and then rerun the script. Additional settings can be placed directly in the echo or in master.cf outside of the build tags.

##DEVNOTE: smtp-amavis not necessary. All others are.

echo "
smtp-amavis  unix  -    -       y       -       2       smtp
    -o smtp_data_done_timeout=1200
    -o disable_dns_lookups=yes
    -o smtp_send_xforward_command=yes

dovecot   unix  -       n       n       -       -       pipe
  flags=DRhu user=mailreader:mail argv=/usr/libexec/dovecot/deliver -f \${sender} -d \${recipient}
127.0.0.1:10025 inet    n       -       y       -       -       smtpd
       -o content_filter=
       -o local_recipient_maps=
       -o relay_recipient_maps=
       -o smtpd_restriction_classes=
       -o smtpd_helo_restrictions=
       -o smtpd_sender_restrictions=
       -o smtpd_recipient_restrictions=permit_mynetworks,reject
       -o mynetworks=127.0.0.0/8
       -o strict_rfc821_envelopes=yes
       -o receive_override_options=no_header_body_checks,no_unknown_recipient_checks
smtp      inet  n       -       n       -       -       smtpd
  -o content_filter=smtp-amavis:127.0.0.1:10024
submission inet n       -       n       -       -       smtpd
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_relay_restrictions=permit_mynetworks,permit_sasl_authenticated,defer_unauth_destination
  -o milter_macro_daemon_name=ORIGINATING
smtps     inet  n       -       n       -       -       smtpd
  -o content_filter=smtp-amavis:127.0.0.1:10024
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_relay_restrictions=permit_mynetworks,permit_sasl_authenticated,defer_unauth_destination
  -o milter_macro_daemon_name=ORIGINATING

" | sudo tee -a "$postfix_dir$postfix_master"

echo "" | sudo tee -a "$postfix_dir$postfix_master"
echo "####END OF CURRENT BUILD... YOU MAY ADJUST SETTINGS OUTSIDE OF THIS TAG, OR IF YOU WISH TO CHANGE SETTINGS IN THIS TAG, ADJUST postfix.sh AND RERUN THE SETUP" | sudo tee -a "$postfix_dir$postfix_master"
echo "Finished building."

#Time to make some self-signed certificates for the mail server

if ! [ -d "/etc/pki/tls/certs" ]; then

sudo mkdir /etc/pki/tls/certs

fi

if ! [ -d "/etc/pki/tls/private" ]; then

sudo mkdir /etc/pki/tls/private

fi

sudo chmod 700 -R /etc/pki/tls/private

#If you want to use more official certificates place them in the certs folder (or anywhere you'd like) and change $smtpd_tls_key_file and $smtpd_tls_cert_file in super.sh to reference the correct files. If you don't make these changes, your official certs won't be used.

sudo mkdir /etc/ssl/private
sudo chmod 777 /etc/ssl/private 
sudo chmod 777 /etc/ssl/certs

sudo ./mkcert.sh

sudo chmod 755 /etc/ssl/certs
sudo chmod 700 /etc/ssl/private

if ! [ -f "$smtpd_tls_cert_file" ]; then

    sudo cp "/etc/ssl/certs/dovecot.pem" "$smtpd_tls_cert_file"

fi

if ! [ -f "$smtpd_tls_key_file" ]; then

    sudo cp "/etc/ssl/private/dovecot.pem" "$smtpd_tls_key_file"

fi

echo "
cert file will be stored in /etc/pki/tls/certs/server.crt
key file will be stored in /etc/pki/tls/private/server.pem
"

#All should be running smoothly for postfix, so let's try to start it up!

sudo postfix start
