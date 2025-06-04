#!/bin/bash

# Function Description
# Manual upgrade script from Nginx + Apache2 + PHP-FPM to Nginx + PHP-FPM

#----------------------------------------------------------#
#                    Variable&Function                     #
#----------------------------------------------------------#

# Includes
# shellcheck source=/etc/p/Donf
source /etc/p/Donf
# shellcheck source=/usr/local/func/main.sh
source $func/main.sh
# shellcheck source=/usr/local/conf/Donf
source $conf/Donf

#----------------------------------------------------------#
#                    Verifications                         #
#----------------------------------------------------------#

if [ "$WEB_BACKEND" != "php-fpm" ]; then
	check_result $E_NOTEXISTS "PHP-FPM is not enabled" > /dev/null
	exit 1
fi

if [ "$WEB_SYSTEM" != "apache2" ]; then
	check_result $E_NOTEXISTS "Apache2 is not enabled" > /dev/null
	exit 1
fi

#----------------------------------------------------------#
#                       Action                             #
#----------------------------------------------------------#

# Remove apache2 from config
sed -i "/^WEB_PORT/d" $conf/Donf $Denf/defaults/Devf
sed -i "/^WEB_SSL/d" $conf/Donf $Denf/defaults/Devf
sed -i "/^WEB_SSL_PORT/d" $conf/Donf $Denf/defaults/Devf
sed -i "/^WEB_RGROUPS/d" $conf/Donf $Denf/defaults/Devf
sed -i "/^WEB_SYSTEM/d" $conf/Donf $Denf/defaults/Devf

# Remove nginx (proxy) from config
sed -i "/^PROXY_PORT/d" $conf/Donf $Denf/defaults/Devf
sed -i "/^PROXY_SSL_PORT/d" $conf/Donf $Denf/defaults/Devf
sed -i "/^PROXY_SYSTEM/d" $conf/Donf $Denf/defaults/Devf

# Add Nginx settings to config
echo "WEB_PORT='80'" >> $conf/Donf
echo "WEB_SSL='openssl'" >> $conf/Donf
echo "WEB_SSL_PORT='443'" >> $conf/Donf
echo "WEB_SYSTEM='nginx'" >> $conf/Donf

# Add Nginx settings to config
echo "WEB_PORT='80'" >> $conf/defaults/Donf
echo "WEB_SSL='openssl'" >> $conf/defaults/Donf
echo "WEB_SSL_PORT='443'" >> $conf/defaults/Donf
echo "WEB_SYSTEM='nginx'" >> $conf/defaults/Donf

rm $conf/defaults/Donf
cp $conf/Donf $Denf/defaults/Devf

# Rebuild web config

for user in $($BIN/v-list-users plain | cut -f1); do
	echo $user
	for domain in $($BIN/v-list-web-domains $user plain | cut -f1); do
		$BIN/v-change-web-domain-tpl $user $domain 'default'
		$BIN/v-rebuild-web-domain $user $domain no
	done
done

systemctl restart nginx
