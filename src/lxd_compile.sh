#!/bin/bash

branch=${1-main}

apt -y install curl wget

curl https://raw.githubusercontent.com/p/D/$branch/src/hst_autocompile.sh > /tmp/hst_autocompile.sh
chmod +x /tmp/hst_autocompile.sh

mkdir -p /opt/p

# Building if bash /tmp/hst_autocompile.sh ----noinstall --keepbuild $branch; then
	cp /tmp/p-src/deb/*.deb /opt/D/
fi

# Building PHP
if bash /tmp/hst_autocompile.sh --php --noinstall --keepbuild $branch; then
	cp /tmp/p-src/deb/*.deb /opt/D/
fi

# Building NGINX
if bash /tmp/hst_autocompile.sh --nginx --noinstall --keepbuild $branch; then
	cp /tmp/p-src/deb/*.deb /opt/D/
fi
