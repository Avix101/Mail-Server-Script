#!/bin/bash
#
#-----------------------------------------#
###Welcome to the pgsql setup script. Any variables that may need to be adjusted should be changed in the designated "variables" section in the main script
#-----------------------------------------#
#First every postgresql element must be installed

sudo yum install postgresql postgresql-server postgresql-devel postgresql-contrib postgresql-docs postgresql-server postgresql-libs -y

#Initialize the database so that we have something to work with

#sudo mkdir -p  $PGDATA
#sudo chown postgres:postgres /mnt/vmail/db

#pg_database=(PGDATA PGLOG)

#for var in ${pg_database[*]}; do
#    temp="$(sudo grep -n ^$var $init_script | sudo grep -o '[0-9]*')"
#    if [ "$temp" != "" ]; then
#        echo "Updating variable..." 
#        sudo sed -i "${temp}d" $init_script
#    fi
#    temp2="$var=${!var}"
#    echo "Writing variable..."
#    sudo sed -i "${temp}i${temp2}" "$init_script"
#
#done

#temp="$(sudo grep -n ^PGDATA $var_store | cut -f1 -d:)"

if [ "$temp" != "" ]; then
    echo "Updating variable..." 
    sudo sed -i "${temp}d" $var_store
fi

if ! [ -e $path_to_hba ]; then

   #su - postgres -c "initdb -D $PGDATA"
    sudo service postgresql initdb

fi
#Grab permissions from pg_hba.conf

local="$(sudo grep ^local $path_to_hba)"
host="$(sudo grep -m 1 ^'host    all' $path_to_hba)"

#If there is a local line, replace it with something that allows for immediate access or write one in. This is a temporary, but necessary change to accomplish everything via a script.

if ! [ "$local" = "" ]; then
sudo ./perl-find-replace "$local" "local all all trust" $path_to_hba
else
echo "local all all trust" | sudo tee -a "$path_to_hba"
fi

#Stop and start postgresql. If postgresql wasn't running, this might throw a trivial error. Ignore

status="$(ps ax | grep -v grep | grep postmaster)"

if [ "$status" = "" ]; then
 
    sudo service postgresql start

else

    sudo service postgresql restart

fi

#Log into the database as postgres user. In the next few lines (until EOF) set variables, create tables, and change permissions

psql -U postgres -v post_pass=$database_pass -v mail_pass=$database_pass <<EOF
\set post_password '\'' :post_pass '\''
ALTER USER postgres PASSWORD :post_password;

\set mail_password '\'' :mail_pass '\''
CREATE USER mailreader WITH PASSWORD :mail_password;
CREATE USER sa WITH PASSWORD :mail_password;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT CREATE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO postgres;

CREATE DATABASE sa_bayes WITH OWNER sa;
CREATE DATABASE mail WITH OWNER mailreader;
\c mail

CREATE TABLE users (
    email TEXT NOT NULL,
    password TEXT NOT NULL,
    realname TEXT,
    created TIMESTAMP WITH TIME ZONE DEFAULT now(),
    PRIMARY KEY (email)
);

CREATE TABLE transports (
    domain  TEXT NOT NULL,
    gid INTEGER NOT NULL,
    transport TEXT NOT NULL,
    PRIMARY KEY (domain)
);

CREATE TABLE aliases (
    alias TEXT NOT NULL,
    email TEXT NOT NULL,
    PRIMARY KEY (alias)
);

ALTER DATABASE mail OWNER TO mailreader;
ALTER TABLE users OWNER TO mailreader;
ALTER TABLE transports OWNER TO mailreader;
ALTER TABLE aliases OWNER TO mailreader;

EOF

#At this point postgresql should be up and running.

wget http://svn.apache.org/repos/asf/spamassassin/branches/3.4/sql/bayes_pg.sql

psql -U sa sa_bayes -f bayes_pg.sql

gid="$(grep ^mail:x /etc/group | grep -o '[0-9]*')"

admin_status="$(psql -U postgres -d mail -c "SELECT email FROM users WHERE email = 'admin@$mydomain'"| grep admin@$mydomain)"

if [ "$admin_status" == "" ]; then

    final_admin_pass="$(doveadm pw -p $database_pass -s ssha512 -r 100)"
    admin_account="admin@$mydomain"
    psql -U postgres -v admin_pass=$final_admin_pass -v admin_email=$admin_account <<EOF
    \c mail

    \set password '\'' :admin_pass '\''
    \set admin '\'' :admin_email '\''

    INSERT INTO users (
    email, 
    password, 
    realname
    ) VALUES (
    :admin, 
    :password, 
    'Admin' 
    );

EOF

else

    echo "Admin account is already in the system, update manually if necessary."

fi

virtual_transport_array=( $virtual_mailbox_domains )

for transport in ${virtual_transport_array[*]}; do

    transport_status="$(psql -U postgres -d mail -c "SELECT domain FROM transports WHERE gid = $gid"| grep $transport)"

if [ "$transport_status" == "" ]; then
    
    echo "Transport table doesn't contain this entry... adding now."    

    psql -U postgres -v domain=$transport -v gid=$gid <<EOF
    
    \c mail

    \set mydomain '\'' :domain '\''

    INSERT INTO transports (
    domain, 
    gid,
    transport
    ) VALUES (
    :mydomain,
    :gid,
    'lmtp:unix:private/dovecot-lmtp'
    );


EOF

else

    echo "Transport table already contains all default entries."

fi

done

sudo mkdir $postfix_dir$path_to_pgsql

sudo chmod -R 666 /etc/postfix/pgsql/

sudo touch /etc/postfix/pgsql/mailboxes.cf
sudo touch /etc/postfix/pgsql/transport.cf
sudo touch /etc/postfix/pgsql/pgsql-aliases.cf

user=$mailreader_user
password=$database_pass
#dbname=$dbname #Perhaps this is obvious (change this setting if you want here or in super.sh)
hosts=localhost
query="SELECT regexp_replace(email, '(.*)@(.*)', '\2/\1')||'/' FROM users WHERE lower(email)=lower('%s')"
file="/mailboxes.cf"

mailboxes_pgsql=(user password dbname hosts query)

for var in ${mailboxes_pgsql[*]}; do
    temp="$(grep ^$var $postfix_dir$path_to_pgsql$file)"
    if [ "$var" == "query" ];then
    sudo sed -i "/Special_tag/,/END_Special_tag/d" "$postfix_dir$path_to_pgsql$file"
    echo "####Special_tag" | sudo tee -a "$postfix_dir$path_to_pgsql$file"
    echo "$var = ${!var}" | sudo tee -a "$postfix_dir$path_to_pgsql$file"
    echo "####END_Special_tag" | sudo tee -a "$postfix_dir$path_to_pgsql$file"

    elif [ "$temp" != "" ]; then
        echo "Updating variable..." 
        sudo ./perl-find-replace "$temp" "$var = ${!var}" "$postfix_dir$path_to_pgsql$file"
    else
        echo "Writing variable..."
        echo "$var = ${!var}" | sudo tee -a "$postfix_dir$path_to_pgsql$file"
    fi
    
done

table=transports
select_field=transport
where_field=domain
file="/transport.cf"

transport_pgsql=(user password dbname table select_field where_field hosts)

for var in ${transport_pgsql[*]}; do
    temp="$(grep ^$var $postfix_dir$path_to_pgsql$file)"
    if [ "$temp" != "" ]; then
        echo "Updating variable..." 
        sudo ./perl-find-replace "$temp" "$var=${!var}" "$postfix_dir$path_to_pgsql$file"
    else
        echo "Writing variable..."
        echo "$var=${!var}" | sudo tee -a "$postfix_dir$path_to_pgsql$file"
    fi
    
done

table=aliases
select_field=email
where_field=alias
hosts=unix:/var/run/postgresql
file="/pgsql-aliases.cf"

aliases_pgsql=(user password dbname table select_field where_field hosts)

for var in ${aliases_pgsql[*]}; do
    temp="$(grep ^$var $postfix_dir$path_to_pgsql$file)"
    if [ "$temp" != "" ]; then
        echo "Updating variable..." 
        sudo ./perl-find-replace "$temp" "$var = ${!var}" "$postfix_dir$path_to_pgsql$file"
    else
        echo "Writing variable..."
        echo "$var = ${!var}" | sudo tee -a "$postfix_dir$path_to_pgsql$file"
    fi
    
done

while ! [ "$host" = "" ]; do
    
    sudo ./perl-find-replace "$host" "#$host" $path_to_hba
    host="$(sudo grep -m 1 ^'host    all' $path_to_hba)"

done

local="$(sudo grep ^local $path_to_hba)"

if ! [ "$local" = "" ]; then
sudo ./perl-find-replace "$local" "local all all md5" $path_to_hba
else
echo "local all all md5" | sudo tee -a "$path_to_hba"
fi

sudo sed -i "/Special_tag/,/END_Special_tag/d" "$path_to_hba"
echo "####Special_tag" | sudo tee -a "$path_to_hba"
echo "

host    all     all        0.0.0.0/0            md5          
host mail mailreader 127.0.0.1/32 md5
host mail mailreader ::1/128 md5

" | sudo tee -a "$path_to_hba"
echo "####END_Special_tag" | sudo tee -a "$path_to_hba"

sudo service postgresql restart
