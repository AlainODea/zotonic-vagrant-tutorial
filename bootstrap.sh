#!/bin/bash
ZOTONIC_RELEASE=release-0.12.1
POSTGRES_RELEASE=9.3

# set locale
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_CTYPE="en_US.UTF-8"
export LC_NUMERIC="en_US.UTF-8"
export LC_TIME="en_US.UTF-8"
export LC_COLLATE="en_US.UTF-8"
export LC_MONETARY="en_US.UTF-8"
export LC_MESSAGES="en_US.UTF-8"
export LC_PAPER="en_US.UTF-8"
export LC_NAME="en_US.UTF-8"
export LC_ADDRESS="en_US.UTF-8"
export LC_TELEPHONE="en_US.UTF-8"
export LC_MEASUREMENT="en_US.UTF-8"
export LC_IDENTIFICATION="en_US.UTF-8"
export LC_ALL=

# install packages
apt-get -y update
apt-get -y install \
    ack-grep build-essential git curl \
    imagemagick postgresql postgresql-contrib \
    erlang-nox erlang-dev inotify-tools

echo

# setup database
echo Check for zotonic database user
echo \\dg | sudo -u postgres psql | grep zotonic
if [ 0 -ne $? ]; then
    cat | sudo -u postgres psql <<EOF
CREATE USER zotonic with password '';
EOF
fi

echo

echo Check for zotonic database
echo \\l | sudo -u postgres psql | grep zotonic
if [ 0 -ne $? ]; then
    cat | sudo -u postgres psql <<EOF
CREATE DATABASE zotonic_verafin WITH
OWNER zotonic
ENCODING 'UTF-8'
LC_CTYPE 'en_US.utf8'
LC_COLLATE 'en_US.utf8'
TEMPLATE template0;
-- Create the schema for the tutorial site
\c zotonic_verafin
\i /vagrant/verafin.com/backup/zotonic_verafin.sql
EOF
fi

cat >> /etc/postgresql/$POSTGRES_RELEASE/main/pg_hba.conf <<EOF
# Zotonic settings
local   all         zotonic                           ident
host    all         zotonic     all                   md5
EOF
/etc/init.d/postgresql reload

# cloning and building zotonic
if [ ! -d /zotonic ]; then
    cd /
    git clone http://github.com/zotonic/zotonic

    # symlink the tutorial website into zotonic's config
    (mkdir -p zotonic/user/sites &&
     cd zotonic/user/sites &&
     ln -s /vagrant/verafin.com verafin)
fi

# now build it...
cd /zotonic
git checkout $ZOTONIC_RELEASE
make

chown vagrant:vagrant /zotonic -R

# and start!
sudo -u vagrant -i /zotonic/bin/zotonic start

CONFIG=$(find $HOME/.zotonic -name zotonic.config | head -n 1)
while [ ! -f $CONFIG ]
do
    sleep 2
done
PASSWORD=`cat $CONFIG | grep {password | sed -E 's/^\s\{\s*password\s*,\s*"(.*?)".*/\1/'`

/zotonic/bin/zotonic modules activate \
    mod_rest mod_base_site mod_admin_frontend \
    mod_admin_modules mod_authentication mod_acl_adminonly \
    mod_mqtt mod_editor_tinymce

if wget -q -O /dev/null http://localhost:8000/; then
    echo "
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Zotonic has been successfully installed:
- Visit http://localhost:8000/ to see the sites administration page.
- The password for login to this page is $PASSWORD
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
else
    echo "Error running Zotonic!"
    # run debug mode to see whats going on
    sudo -u vagrant -i /zotonic/bin/zotonic debug
fi
