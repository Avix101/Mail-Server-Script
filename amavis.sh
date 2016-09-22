#!/bin/bash
#
#-----------------------------------------#
###Welcome to the Amavis / Clamav / Spamassassin setup script. Any variables that may need to be adjusted should be changed in the designated "variables" section in the main script. Some non variable file writes should be changed in this file if necessary though.
#-----------------------------------------#

if [ "$package_manager" = "yum" ]; then

    sudo rpm -Uvh http://repoforge.mirror.digitalpacific.com.au/redhat/el6/en/x86_64/rpmforge/RPMS/rpmforge-release-0.5.2-2.el6.rf.x86_64.rpm
    
    #Fixing broken dependencies
    old="baseurl"
    new="baseurl = http://repoforge.mirror.constant.com/redhat/el6/en/x86_64/rpmforge/"
    sudo sed -i "/${old}/c\\${new}" /etc/yum.repos.d/rpmforge*
    
    old="mirrorlist"
    new="mirrorlist = http://repoforge.mirror.constant.com/redhat/el6/en/x86_64/rpmforge/"
    sudo sed -i "/${old}/c\\${new}" /etc/yum.repos.d/rpmforge*

fi

#http://repoforge.mirror.constant.com/redhat/el6/en/x86_64/rpmforge/
#http://repoforge.mirror.constant.com/redhat/el6/en/x86_64/rpmforge/RPMS/rpmforge-release-0.5.2-2.el6.rf.x86_64.rpm

sudo $package_manager install amavisd-new clamd perl-IO-Socket-INET6 -y

sudo $package_manager install perl-Razor-Agent perl-DBD-Pg -y


start_tag="####CURRENT BUILD !!!! LEAVE THIS TAG LINE INTACT IF YOU PLAN TO EVER USE THE SETUP SCRIPT AGAIN OR BE READY TO REINSTALL DOVECOT... DO NOT REMOVE####"
end_tag="####END OF CURRENT BUILD... YOU MAY ADJUST SETTINGS OUTSIDE OF THIS TAG, OR IF YOU WISH TO CHANGE SETTINGS IN THIS TAG, ADJUST dovecot.sh AND RERUN THE SETUP"

amavis_settings=(MYHOME myhostname mydomain sa_spam_subject_tag undecipherable_subject_tag sa_tag_level_deflt sa_tag2_level_deflt bypass_virus_checks_maps)


for var in ${amavis_settings[*]}; do
    temp="$(sudo grep -n ^\$$var $amavis_conf | cut -f1 -d:)"
    temp2="\$$var = \"${!var}\";"
    if [ "$temp" != "" ]; then
        echo "Updating variable..." 
        sudo sed -i "${temp}d" $amavis_conf
        sudo sed -i "${temp}i${temp2}" $amavis_conf
    else
        echo "Writing variable..."
        echo "\$$var = \"${!var}\";" | sudo tee -a "$amavis_conf"
    fi

done

sudo ./perl-find-replace "killproc \\\$prog" "killproc -p $amavis_pid" "$amavis_init"

sudo ./perl-find-replace "status \\\$prog" "status -p $amavis_pid" "$amavis_init"

start_tag="####CURRENT BUILD !!!! LEAVE THIS TAG LINE INTACT IF YOU PLAN TO EVER USE THE SETUP SCRIPT AGAIN OR BE READY TO REINSTALL DOVECOT... DO NOT REMOVE####"
end_tag="####END OF CURRENT BUILD... YOU MAY ADJUST SETTINGS OUTSIDE OF THIS TAG, OR IF YOU WISH TO CHANGE SETTINGS IN THIS TAG, ADJUST dovecot.sh AND RERUN THE SETUP"

temp="$(sudo grep -n ^@local_domains_maps $amavis_conf | cut -f1 -d:)"
if [ "$temp" != "" ]; then
 
    sudo sed -i "${temp}d" $amavis_conf

fi

domain_array=( $virtual_mailbox_domains )

domains="\".\$mydomain\""

for var in ${domain_array[*]}; do

domains=$domains", '.$var'"

done

sudo sed -i "/$start_tag/,/$end_tag/d" "$amavis_conf"

echo "$start_tag
@local_domains_maps = ( [ $domains ] );
@sa_username_maps = new_RE ( [ qr'(.*)'i => '\${1}' ]);
$end_tag" | sudo tee -a "$amavis_conf"

#sudo ./perl-find-replace "example.com" "$mydomain" "$amavis_conf"

sudo mkdir -p /var/amavis/.razor/
sudo touch /var/amavis/.razor/razor-agent.conf

sudo mkdir -p /var/amavis/.spamassassin/
sudo ln -s /etc/mail/spamassassin/local.cf /var/amavis/.spamassassin/user_prefs

sudo sed -i "/$start_tag/,/$end_tag/d" "/var/amavis/.razor/razor-agent.conf"

echo "$start_tag

#
# Razor2 config file
# 
# see razor-agent.conf(5) man page 
#

debuglevel             = 3
identity               = identity
ignorelist             = 0
listfile_catalogue     = servers.catalogue.lst
listfile_discovery     = servers.discovery.lst
listfile_nomination    = servers.nomination.lst
logfile                = razor-agent.log
logic_method           = 4
min_cf                 = ac
razordiscovery         = discovery.razor.cloudmark.com
rediscovery_wait       = 172800
report_headers         = 1
turn_off_discovery     = 0
use_engines            = 4,8
whitelist              = razor-whitelist

$end_tag" | sudo tee -a "/var/amavis/.razor/razor-agent.conf"

sudo sed -i "1,10d" "$spamassassin_conf"

spamassassin_settings=(required_hits report_safe required_score rewrite_header)

for var in ${spamassassin_settings[*]}; do
    temp="$(sudo grep ^$var $spamassassin_conf)"
    if [ "$temp" != "" ]; then
        echo "Updating variable..." 
        sudo ./perl-find-replace "$temp" "$var ${!var}" "$spamassassin_conf"
    else
        echo "Writing variable..."
        echo "$var ${!var}" | sudo tee -a "$spamassassin_conf"
    fi
    
done

sudo sed -i "/$start_tag/,/$end_tag/d" "$spamassassin_conf"

echo "$start_tag

# These values can be overridden by editing ~/.spamassassin/user_prefs.cf 
# (see spamassassin(1) for details)

# These should be safe assumptions and allow for simple visual sifting
# without risking lost emails.

# Enable the Bayes system
use_bayes 1

# Enable Bayes auto-learning
bayes_auto_learn 1

# Enable or disable network checks
use_razor2 1
razor_config /var/amavis/.razor/razor-agent.conf

bayes_store_module Mail::SpamAssassin::BayesStore::PgSQL
bayes_sql_dsn DBI:Pg:dbname=sa_bayes;host=localhost
bayes_sql_username sa
bayes_sql_password $default_password

score BAYES_999 4.0

$end_tag" | sudo tee -a "$spamassassin_conf"

sudo groupadd spamfilter
sudo useradd -g spamfilter -s /bin/false -d /usr/local/spamassassin spamfilter
sudo chown spamfilter: /usr/local/spamassassin

status="$(ps ax | grep -v grep | grep spamd)"

if [ "$status" = "" ]; then 

    sudo service spamassassin start

else

    sudo service spamassassin restart

fi

while [ "$(sudo lsof -i :10024)" != "" ]; do

amavis_start="$(sudo lsof -i :10024 | grep -o '[0-9]*' | head -1)"
sudo kill -KILL $amavis_start

done

