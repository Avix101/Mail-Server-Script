#!/bin/bash
#
#-----------------------------------------#
###Welcome to the spamassassin learning script.
#-----------------------------------------#

pass=$(grep -E "^password\s*=" /etc/postfix/pgsql/mailboxes.cf | sed 's/.*=\s*//')

users=($(PGPASSWORD=$pass psql -t -U mailreader -d mail -c "SELECT email FROM users"))

for user in "${users[@]}"; do
echo "Processing $user..."
IFS='@' read -a array <<< "$user"

USER="${array[0]}"
DOMAIN="${array[1]}"

if [ "$1" == 'spam' ]; then

    sa-learn --spam -u "$USER@$DOMAIN" /mnt/vmail/$DOMAIN/$USER/.Junk/cur

elif [ "$1" == 'ham' ]; then

    sa-learn --ham  -u "$USER@$DOMAIN" /mnt/vmail/$DOMAIN/$USER/cur

fi

done


