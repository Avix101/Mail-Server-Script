#!/bin/bash
#
#-----------------------------------------#
###Welcome to the crontab setup script. 
#-----------------------------------------#

sudo $package_manager install cronie -y

sudo crontab -u amavis -r

sudo crontab -u amavis -l | { cat; echo "0 5 * * * nohup time /mnt/vmail/learn.sh spam >> /mnt/vmail/learn-spam.nohup 2>&1 &
0 7 * * 0 nohup time /mnt/vmail/learn.sh ham >> /mnt/vmail/learn-ham.nohup 2>&1 &"; } | sudo crontab -u amavis -

temp="$(grep ^pass learn.sh)"
if [ "$temp" != "" ]; then
    echo "Updating variable..." 
    sudo ./perl-find-replace "$temp" "pass=$database_pass" "learn.sh"
else
    echo "Writing variable..."
    echo "pass=$database_pass" | sudo tee -a "learn.sh"
fi

sudo cp learn.sh /mnt/vmail/learn.sh
