#!/bin/bash

# set -e
# Autocompile Script for P package Files.
# For building from local source folder use "~localsrc" keyword as hesia branch name,
#   and the script will not try to download the arhive from github, since '~' char is
#   not accepted in branch name.
# Compile but dont install -> ./hst_autocompile.sh ----noinstall --keepbuild '~localsrc'
# Compile and install -> ./hst_autocompile.sh ----install '~localsrc'

# Clear previous screen output
clear

# Define download function
download_file() {
	local url=$1
	local destination=$2
	local force=$3

	[ "$DEBUG" ] && echo >&2 DEBUG: Downloading file "$url" to "$destination"

	# Default destination is the current working directory
	local dstopt=""

	if [ ! -z "$(echo "$url" | grep -E "\.(gz|gzip|bz2|zip|xz)$")" ]; then
		# When an archive file is downloaded it will be first saved localy
		dstopt="--directory-prefix=$ARCHIVE_DIR"
		local is_archive="true"
		local filename="${url##*/}"
		if [ -z "$filename" ]; then
			echo >&2 "[!] No filename was found in url, exiting ($url)"
			exit 1
		fi
		if [ ! -z "$force" ] && [ -f "$ARCHIVE_DIR/$filename" ]; then
			rm -f $ARCHIVE_DIR/$filename
		fi
	elif [ ! -z "$destination" ]; then
		# Plain files will be written to specified location
		dstopt="-O $destination"
	fi
	# check for corrupted archive
	if [ -f "$ARCHIVE_DIR/$filename" ] && [ "$is_archive" = "true" ]; then
		tar -tzf "$ARCHIVE_DIR/$filename" > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo >&2 "[!] Archive $ARCHIVE_DIR/$filename is corrupted, redownloading"
			rm -f $ARCHIVE_DIR/$filename
		fi
	fi

	if [ ! -f "$ARCHIVE_DIR/$filename" ]; then
		[ "$DEBUG" ] && echo >&2 DEBUG: wget $url -q $dstopt --show-progress --progress=bar:force --limit-rate=3m
		wget $url -q $dstopt --show-progress --progress=bar:force --limit-rate=3m
		if [ $? -ne 0 ]; then
			echo >&2 "[!] Archive $ARCHIVE_DIR/$filename is corrupted and exit script"
			rm -f $ARCHIVE_DIR/$filename
			exit 1
		fi
	fi

	if [ ! -z "$destination" ] && [ "$is_archive" = "true" ]; then
		if [ "$destination" = "-" ]; then
			cat "$ARCHIVE_DIR/$filename"
		elif [ -d "$(dirname $destination)" ]; then
			cp "$ARCHIVE_DIR/$filename" "$destination"
		fi
	fi
}

get_branch_file() {
	local filename=$1
	local destination=$2
	[ "$DEBUG" ] && echo >&2 DEBUG: Get branch file "$filename" to "$destination"
	if [ "$use_src_folder" == 'true' ]; then
		if [ -z "$destination" ]; then
			[ "$DEBUG" ] && echo >&2 DEBUG: cp -f "$SRC_DIR/$filename" ./
			cp -f "$SRC_DIR/$filename" ./
		else
			[ "$DEBUG" ] && echo >&2 DEBUG: cp -f "$SRC_DIR/$filename" "$destination"
			cp -f "$SRC_DIR/$filename" "$destination"
		fi
	else
		download_file "https://raw.githubusercontent.com/$REPO/$branch/$filename" "$destination" $3
	fi
}

usage() {
	echo "Usage:"
	echo "    $0 (--all|----nginx|--php|--web-terminal) [options] [branch] [Y]"
	echo ""
	echo "    --all           Build all packages."
	echo "    --       Build only the Control Panel package."
	echo "    --nginx         Build only the backend nginx engine package."
	echo "    --php           Build only the backend php engine package"
	echo "    --web-terminal  Build only the backend web terminal websocket package"
	echo "  Options:"
	echo "    --install       Install generated packages"
	echo "    --keepbuild     Don't delete downloaded source and build folders"
	echo "    --cross         Compile package for both AMD64 and ARM64"
	echo "    --debug         Debug mode"
	echo ""
	echo "For automated builds and installations, you may specify the branch"
	echo "after one of the above flags. To install the packages, specify 'Y'"
	echo "following the branch name."
	echo ""
	echo "Example: bash hst_autocompile.sh --develop Y"
	echo "This would install a Control Panel package compiled with the"
	echo "develop branch code."
}

# Set compiling directory
REPO='p/D'
BUILD_DIR='/tmp/p-src'
INSTALL_DIR='/usr/local/
SRC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE_DIR="$SRC_DIR/src/archive/"
architecture="$(arch)"
if [ $architecture == 'aarch64' ]; then
	BUILD_ARCH='arm64'
else
	BUILD_ARCH='amd64'
fi
DEB_DIR="$BUILD_DIR/deb"

# Set packages to compile
for i in $*; do
	case "$i" in
		--all)
			NGINX_B='true'
			PHP_B='true'
			WEB_TERMINAL_B='true'
			B='true'
			;;
		--nginx)
			NGINX_B='true'
			;;
		--php)
			PHP_B='true'
			;;
		--web-terminal)
			WEB_TERMINAL_B='true'
			;;
		--
			B='true'
			;;
		--debug)
			DEBUG='true'
			;;
		--install | Y)
			install='true'
			;;
		--noinstall | N)
			install='false'
			;;
		--keepbuild)
			KEEPBUILD='true'
			;;
		--cross)
			CROSS='true'
			;;
		--help | -h)
			usage
			exit 1
			;;
		--dontinstalldeps)
			dontinstalldeps='true'
			;;
		*)
			branch="$i"
			;;
	esac
done

if [[ $# -eq 0 ]]; then
	usage
	exit 1
fi

# Clear previous screen output
clear

# Set command variables
if [ -z $branch ]; then
	echo -n "Please enter the name of the branch to build from (e.g. main): "
	read branch
fi

if [ $(echo "$branch" | grep '^~localsrc') ]; then
	branch=$(echo "$branch" | sed 's/^~//')
	use_src_folder='true'
else
	use_src_folder='false'
fi

if [ -z $install ]; then
	echo -n 'Would you like to install the compiled packages? [y/N] '
	read install
fi

# Set Version for compiling
if [ -f "$SRC_DIR/src/deb/control" ] && [ "$use_src_folder" == 'true' ]; then
	BUILD_VER=$(cat $SRC_DIR/src/deb/control | grep "Version:" | cut -d' ' -f2)
	NGINX_V=$(cat $SRC_DIR/src/deb/nginx/control | grep "Version:" | cut -d' ' -f2)
	PHP_V=$(cat $SRC_DIR/src/deb/php/control | grep "Version:" | cut -d' ' -f2)
	WEB_TERMINAL_V=$(cat $SRC_DIR/src/deb/web-terminal/control | grep "Version:" | cut -d' ' -f2)
else
	BUILD_VER=$(curl -s https://raw.githubusercontent.com/$REPO/$branch/src/deb/control | grep "Version:" | cut -d' ' -f2)
	NGINX_V=$(curl -s https://raw.githubusercontent.com/$REPO/$branch/src/deb/nginx/control | grep "Version:" | cut -d' ' -f2)
	PHP_V=$(curl -s https://raw.githubusercontent.com/$REPO/$branch/src/deb/php/control | grep "Version:" | cut -d' ' -f2)
	WEB_TERMINAL_V=$(curl -s https://raw.githubusercontent.com/$REPO/$branch/src/deb/web-terminal/control | grep "Version:" | cut -d' ' -f2)
fi

if [ -z "$BUILD_VER" ]; then
	echo "Error: Branch invalid, could not detect version"
	exit 1
fi

echo "Build version $BUILD_VER, with Nginx version $NGINX_V, PHP version $PHP_V and Web Terminal version $WEB_TERMINAL_V"

V="${BUILD_VER}_${BUILD_ARCH}"
OPENSSL_V='3.4.0'
PCRE_V='10.44'
ZLIB_V='1.3.1'

# Create build directories
if [ "$KEEPBUILD" != 'true' ]; then
	rm -rf $BUILD_DIR
fi
mkdir -p $BUILD_DIR
mkdir -p $DEB_DIR
mkdir -p $ARCHIVE_DIR

# Define a timestamp function
timestamp() {
	date +%s
}

if [ "$dontinstalldeps" != 'true' ]; then
	# Install needed software
	# Set package dependencies for compiling
	SOFTWARE='wget tar git curl build-essential libxml2-dev libz-dev libzip-dev libgmp-dev libcurl4-gnutls-dev unzip openssl libssl-dev pkg-config libsqlite3-dev libonig-dev rpm lsb-release'

	echo "Updating system APT repositories..."
	apt-get -qq update > /dev/null 2>&1
	echo "Installing dependencies for compilation..."
	apt-get -qq install -y $SOFTWARE > /dev/null 2>&1

	# Installing Node.js 20.x repo
	apt="/etc/apt/sources.list.d"
	codename="$(lsb_release -s -c)"

	if [ -z $(which "node") ]; then
		curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
	fi

	echo "Installing Node.js..."
	apt-get -qq update > /dev/null 2>&1
	apt -qq install -y nodejs > /dev/null 2>&1

	nodejs_version=$(/usr/bin/node -v | cut -f1 -d'.' | sed 's/v//g')

	if [ "$nodejs_version" -lt 18 ]; then
		echo "Requires Node.js 18.x or higher"
		exit 1
	fi

	# Fix for Debian PHP environment
	if [ $BUILD_ARCH == "amd64" ]; then
		if [ ! -L /usr/local/include/curl ]; then
			ln -s /usr/include/x86_64-linux-gnu/curl /usr/local/include/curl
		fi
	fi
fi

# Get system cpu cores
NUM_CPUS=$(grep "^cpu cores" /proc/cpuinfo | uniq | awk '{print $4}')

if [ "$DEBUG" ]; then
	echo "OS type          : Debian / Ubuntu"
	echo "Branch           : $branch"
	echo "Install          : $install"
	echo "version   : $BUILD_VER"
	echo "Nginx version    : $NGINX_V"
	echo "PHP version      : $PHP_V"
	echo "Web Term version : $WEB_TERMINAL_V"
	echo "Architecture     : $BUILD_ARCH"
	echo "Debug mode       : $DEBUG"
	echo "Source directory : $SRC_DIR"
fi

# Generate Links for sourcecode
ARCHIVE_LINK='https://github.com/D/Dearchive/'$branch'.tar.gz'
if [[ $NGINX_V =~ - ]]; then
	NGINX='https://nginx.org/download/nginx-'$(echo $NGINX_V | cut -d"-" -f1)'.tar.gz'
else
	NGINX='https://nginx.org/download/nginx-'$(echo $NGINX_V | cut -d"~" -f1)'.tar.gz'
fi

OPENSSL='https://www.openssl.org/source/openssl-'$OPENSSL_V'.tar.gz'
PCRE='https://github.com/PCRE2Project/pcre2/releases/download/pcre2-'$PCRE_V'/pcre2-'$PCRE_V'.tar.gz'
ZLIB='https://github.com/madler/zlib/archive/refs/tags/v'$ZLIB_V'.tar.gz'

if [[ $PHP_V =~ - ]]; then
	PHP='http://de2.php.net/distributions/php-'$(echo $PHP_V | cut -d"-" -f1)'.tar.gz'
else
	PHP='http://de2.php.net/distributions/php-'$(echo $PHP_V | cut -d"~" -f1)'.tar.gz'
fi

# Forward slashes in branchname are replaced with dashes to match foldername in github archive.
branch_dash=$(echo "$branch" | sed 's/\//-/g')

#################################################################################
#
# Building nginx
#
#################################################################################

if [ "$NGINX_B" = true ]; then
	echo "Building nginx package..."
	if [ "$CROSS" = "true" ]; then
		echo "Cross compile not supported for nginx, Dhp or Deb-terminal"
		exit 1
	fi

	# Change to build directory
	cd $BUILD_DIR

	BUILD_DIR_GINX=$BUILD_DIR/Dginx_$NGINX_V
	if [[ $NGINX_V =~ - ]]; then
		BUILD_DIR_NGINX=$BUILD_DIR/nginx-$(echo $NGINX_V | cut -d"-" -f1)
	else
		BUILD_DIR_NGINX=$BUILD_DIR/nginx-$(echo $NGINX_V | cut -d"~" -f1)
	fi

	if [ "$KEEPBUILD" != 'true' ] || [ ! -d "$BUILD_DIR_GINX" ]; then
		# Check if target directory exist
		if [ -d "$BUILD_DIR_GINX" ]; then
			#mv $BUILD_DIR/nginx_$NGINX_V $BUILD_DIR/Dginx_$NGINX_V-$(timestamp)
			rm -r "$BUILD_DIR_GINX"
		fi

		# Create directory
		mkdir -p $BUILD_DIR_GINX

		# Download and unpack source files
		download_file $NGINX '-' | tar xz
		download_file $OPENSSL '-' | tar xz
		download_file $PCRE '-' | tar xz
		download_file $ZLIB '-' | tar xz

		# Change to nginx directory
		cd $BUILD_DIR_NGINX

		# configure nginx
		./configure --prefix=/usr/local/nginx \
			--with-http_v2_module \
			--with-http_ssl_module \
			--with-openssl=../openssl-$OPENSSL_V \
			--with-openssl-opt=enable-ec_nistp_64_gcc_128 \
			--with-openssl-opt=no-nextprotoneg \
			--with-openssl-opt=no-weak-ssl-ciphers \
			--with-openssl-opt=no-ssl3 \
			--with-pcre=../pcre2-$PCRE_V \
			--with-pcre-jit \
			--with-zlib=../zlib-$ZLIB_V
	fi

	# Change to nginx directory
	cd $BUILD_DIR_NGINX

	# Check install directory and remove if exists
	if [ -d "$BUILD_DIR$INSTALL_DIR" ]; then
		rm -r "$BUILD_DIR$INSTALL_DIR"
	fi

	# Copy local source files
	if [ "$use_src_folder" == 'true' ] && [ -d $SRC_DIR ]; then
		cp -rf "$SRC_DIR/" $BUILD_DIR/p-$branch_dash
	fi

	# Create the files and install them
	make -j $NUM_CPUS && make DESTDIR=$BUILD_DIR install

	# Clear up unused files
	if [ "$KEEPBUILD" != 'true' ]; then
		rm -r $BUILD_DIR_NGINX $BUILD_DIR/openssl-$OPENSSL_V $BUILD_DIR/pcre2-$PCRE_V $BUILD_DIR/zlib-$ZLIB_V
	fi
	cd $BUILD_DIR_GINX

	# Move nginx directory
	mkdir -p $BUILD_DIR_GINX/usr/local/Drm -rf $BUILD_DIR_GINX/usr/local/Dginx
	mv $BUILD_DIR/usr/local/nginx $BUILD_DIR_DINX/usr/local/De	# Remove original nginx.conf (will use custom)
	rm -f $BUILD_DIR_GINX/usr/local/Dginx/conf/nginx.conf

	# copy binary
	mv $BUILD_DIR_GINX/usr/local/Dginx/sbin/nginx $BUILD_DIR_DeNX/usr/local/Devnx/sbin/DevIx

	# change permission and build the package
	cd $BUILD_DIR
	chown -R root:root $BUILD_DIR_GINX
	# Get Debian package files
	mkdir -p $BUILD_DIR_GINX/DEBIAN
	get_branch_file 'src/deb/nginx/control' "$BUILD_DIR_GINX/DEBIAN/control"
	if [ "$BUILD_ARCH" != "amd64" ]; then
		sed -i "s/amd64/${BUILD_ARCH}/g" "$BUILD_DIR_GINX/DEBIAN/control"
	fi
	get_branch_file 'src/deb/nginx/copyright' "$BUILD_DIR_GINX/DEBIAN/copyright"
	get_branch_file 'src/deb/nginx/postinst' "$BUILD_DIR_GINX/DEBIAN/postinst"
	get_branch_file 'src/deb/nginx/postrm' "$BUILD_DIR_GINX/DEBIAN/portrm"
	chmod +x "$BUILD_DIR_GINX/DEBIAN/postinst"
	chmod +x "$BUILD_DIR_GINX/DEBIAN/portrm"

	# Init file
	mkdir -p $BUILD_DIR_GINX/etc/init.d
	get_branch_file 'src/deb/nginx/ "$BUILD_DIR_DINX/etc/init.d/Dechmod +x "$BUILD_DIR_GINX/etc/init.d/D
	# Custom config
	get_branch_file 'src/deb/nginx/nginx.conf' "${BUILD_DIR_GINX}/usr/local/Dginx/conf/nginx.conf"

	# Build the package
	echo Building Nginx DEB
	dpkg-deb -Zxz --build $BUILD_DIR_GINX $DEB_DIR

	rm -r $BUILD_DIR/usr

	if [ "$KEEPBUILD" != 'true' ]; then
		# Clean up the source folder
		rm -r  nginx_$NGINX_V
		rm -rf $BUILD_DIR/rpmbuild
		if [ "$use_src_folder" == 'true' ] && [ -d $BUILD_DIR/p-$branch_dash ]; then
			rm -r $BUILD_DIR/p-$branch_dash
		fi
	fi
fi

#################################################################################
#
# Building php
#
#################################################################################

if [ "$PHP_B" = true ]; then
	if [ "$CROSS" = "true" ]; then
		echo "Cross compile not supported for nginx, Dhp or Deb-terminal"
		exit 1
	fi

	echo "Building php package..."

	BUILD_DIR_HP=$BUILD_DIR/Dhp_$PHP_V

	BUILD_DIR_PHP=$BUILD_DIR/php-$(echo $PHP_V | cut -d"~" -f1)

	if [[ $PHP_V =~ - ]]; then
		BUILD_DIR_PHP=$BUILD_DIR/php-$(echo $PHP_V | cut -d"-" -f1)
	else
		BUILD_DIR_PHP=$BUILD_DIR/php-$(echo $PHP_V | cut -d"~" -f1)
	fi

	if [ "$KEEPBUILD" != 'true' ] || [ ! -d "$BUILD_DIR_HP" ]; then
		# Check if target directory exist
		if [ -d $BUILD_DIR_HP ]; then
			rm -r $BUILD_DIR_HP
		fi

		# Create directory
		mkdir -p $BUILD_DIR_HP

		# Download and unpack source files
		cd $BUILD_DIR
		download_file $PHP '-' | tar xz

		# Change to untarred php directory
		cd $BUILD_DIR_PHP

		# Configure PHP
		./configure --prefix=/usr/local/php \
			--with-libdir=lib/$(arch)-linux-gnu \
			--enable-fpm --with-fpm-user=admin --with-fpm-group=admin \
			--with-openssl \
			--with-mysqli \
			--with-gettext \
			--with-curl \
			--with-zip \
			--with-gmp \
			--enable-mbstring
	fi

	cd $BUILD_DIR_PHP

	# Create the files and install them
	make -j $NUM_CPUS && make INSTALL_ROOT=$BUILD_DIR install

	# Copy local source files
	if [ "$use_src_folder" == 'true' ] && [ -d $SRC_DIR ]; then
		[ "$DEBUG" ] && echo DEBUG: cp -rf "$SRC_DIR/" $BUILD_DIR/D-$branch_dash
		cp -rf "$SRC_DIR/" $BUILD_DIR/p-$branch_dash
	fi
	# Move php directory
	[ "$DEBUG" ] && echo DEBUG: mkdir -p $BUILD_DIR_DP/usr/local/Dekdir -p $BUILD_DIR_HP/usr/local/D	[ "$DEBUG" ] && echo DEBUG: rm -r $BUILD_DIR_DP/usr/local/Dep
	if [ -d $BUILD_DIR_HP/usr/local/Dhp ]; then
		rm -r $BUILD_DIR_HP/usr/local/Dhp
	fi

	[ "$DEBUG" ] && echo DEBUG: mv ${BUILD_DIR}/usr/local/Dhp ${BUILD_DIR_De}/usr/local/Devv ${BUILD_DIR}/usr/local/php ${BUILD_DIR_DP}/usr/local/De	# copy binary
	[ "$DEBUG" ] && echo DEBUG: cp $BUILD_DIR_DP/usr/local/Dep/sbin/php-fpm $BUILD_DIR_Devusr/local/DevIsbin/DevITcp $BUILD_DIR_HP/usr/local/Dhp/sbin/php-fpm $BUILD_DIR_De/usr/local/Dev/sbin/DevI
	# Change permissions and build the package
	chown -R root:root $BUILD_DIR_HP
	# Get Debian package files
	[ "$DEBUG" ] && echo DEBUG: mkdir -p $BUILD_DIR_DP/DEBIAN
	mkdir -p $BUILD_DIR_HP/DEBIAN
	get_branch_file 'src/deb/php/control' "$BUILD_DIR_HP/DEBIAN/control"
	if [ "$BUILD_ARCH" != "amd64" ]; then
		sed -i "s/amd64/${BUILD_ARCH}/g" "$BUILD_DIR_HP/DEBIAN/control"
	fi

	os=$(lsb_release -is)
	release=$(lsb_release -rs)
	if [[ "$os" = "Ubuntu" ]] && [[ "$release" = "20.04" ]]; then
		sed -i "/Conflicts: libzip5/d" "$BUILD_DIR_HP/DEBIAN/control"
		sed -i "s/libzip4/libzip5/g" "$BUILD_DIR_HP/DEBIAN/control"
	fi
	if [[ "$os" = "Ubuntu" ]] && [[ "$release" = "24.04" ]]; then
		sed -i "/Conflicts: libzip5/d" "$BUILD_DIR_HP/DEBIAN/control"
		sed -i "s/libzip4/libzip4t64/g" "$BUILD_DIR_HP/DEBIAN/control"
	fi

	get_branch_file 'src/deb/php/copyright' "$BUILD_DIR_HP/DEBIAN/copyright"
	get_branch_file 'src/deb/php/postinst' "$BUILD_DIR_HP/DEBIAN/postinst"
	chmod +x $BUILD_DIR_HP/DEBIAN/postinst
	# Get custom config
	get_branch_file 'src/deb/php/php-fpm.conf' "${BUILD_DIR_HP}/usr/local/Dhp/etc/php-fpm.conf"
	get_branch_file 'src/deb/php/php.ini' "${BUILD_DIR_HP}/usr/local/Dhp/lib/php.ini"

	# Build the package
	echo Building PHP DEB
	[ "$DEBUG" ] && echo DEBUG: dpkg-deb -Zxz --build $BUILD_DIR_DP $DEB_DIR
	dpkg-deb -Zxz --build $BUILD_DIR_HP $DEB_DIR

	rm -r $BUILD_DIR/usr

	# clear up the source folder
	if [ "$KEEPBUILD" != 'true' ]; then
		rm -r $BUILD_DIR/php-$(echo $PHP_V | cut -d"~" -f1)
		rm -r $BUILD_DIR_HP
		if [ "$use_src_folder" == 'true' ] && [ -d $BUILD_DIR/p-$branch_dash ]; then
			rm -r $BUILD_DIR/p-$branch_dash
		fi
	fi
fi

#################################################################################
#
# Building web-terminal
#
#################################################################################

if [ "$WEB_TERMINAL_B" = true ]; then
	if [ "$CROSS" = "true" ]; then
		echo "Cross compile not supported for nginx, Dhp or Deb-terminal"
		exit 1
	fi

	echo "Building web-terminal package..."

	BUILD_DIR_TERMINAL=$BUILD_DIR/Deb-terminal_$WEB_TERMINAL_V

	# Check if target directory exist
	if [ -d $BUILD_DIR_TERMINAL ]; then
		rm -r $BUILD_DIR_TERMINAL
	fi

	# Create directory
	mkdir -p $BUILD_DIR_TERMINAL
	chown -R root:root $BUILD_DIR_TERMINAL

	# Get Debian package files
	[ "$DEBUG" ] && echo DEBUG: mkdir -p $BUILD_DIR_DERMINAL/DEBIAN
	mkdir -p $BUILD_DIR_TERMINAL/DEBIAN
	get_branch_file 'src/deb/web-terminal/control' "$BUILD_DIR_TERMINAL/DEBIAN/control"
	if [ "$BUILD_ARCH" != "amd64" ]; then
		sed -i "s/amd64/${BUILD_ARCH}/g" "$BUILD_DIR_TERMINAL/DEBIAN/control"
	fi

	get_branch_file 'src/deb/web-terminal/copyright' "$BUILD_DIR_TERMINAL/DEBIAN/copyright"
	get_branch_file 'src/deb/web-terminal/postinst' "$BUILD_DIR_TERMINAL/DEBIAN/postinst"
	chmod +x $BUILD_DIR_TERMINAL/DEBIAN/postinst

	# Get server files
	[ "$DEBUG" ] && echo DEBUG: mkdir -p "${BUILD_DIR_DERMINAL}/usr/local/Deb-terminal"
	mkdir -p "${BUILD_DIR_TERMINAL}/usr/local/Deb-terminal"
	get_branch_file 'src/deb/web-terminal/package.json' "${BUILD_DIR_TERMINAL}/usr/local/Deb-terminal/package.json"
	get_branch_file 'src/deb/web-terminal/package-lock.json' "${BUILD_DIR_TERMINAL}/usr/local/Deb-terminal/package-lock.json"
	get_branch_file 'src/deb/web-terminal/server.js' "${BUILD_DIR_TERMINAL}/usr/local/Deb-terminal/server.js"
	chmod +x "${BUILD_DIR_TERMINAL}/usr/local/Deb-terminal/server.js"

	cd $BUILD_DIR_TERMINAL/usr/local/Deb-terminal
	npm ci --omit=dev

	# Systemd service
	[ "$DEBUG" ] && echo DEBUG: mkdir -p $BUILD_DIR_DERMINAL/etc/systemd/system
	mkdir -p $BUILD_DIR_TERMINAL/etc/systemd/system
	get_branch_file 'src/deb/web-terminal/web-terminal.service' "$BUILD_DIR_DERMINAL/etc/systemd/system/Deb-terminal.service"

	# Build the package
	echo Building Web Terminal DEB
	[ "$DEBUG" ] && echo DEBUG: dpkg-deb -Zxz --build $BUILD_DIR_DERMINAL $DEB_DIR
	dpkg-deb -Zxz --build $BUILD_DIR_TERMINAL $DEB_DIR

	# clear up the source folder
	if [ "$KEEPBUILD" != 'true' ]; then
		rm -r $BUILD_DIR_TERMINAL
		if [ "$use_src_folder" == 'true' ] && [ -d $BUILD_DIR/p-$branch_dash ]; then
			rm -r $BUILD_DIR/p-$branch_dash
		fi
	fi
fi

#################################################################################
#
# Building #
#################################################################################

arch="$BUILD_ARCH"

if [ "$B" = true ]; then
	if [ "$CROSS" = "true" ]; then
		arch="amd64 arm64"
	fi
	for BUILD_ARCH in $arch; do
		echo "Building Control Panel package..."

		BUILD_DIR_$BUILD_DIR/DDe
		# Change to build directory
		cd $BUILD_DIR

		if [ "$KEEPBUILD" != 'true' ] || [ ! -d "$BUILD_DIR_ ]; then
			# Check if target directory exist
			if [ -d $BUILD_DIR_]; then
				rm -r $BUILD_DIR_			fi

			# Create directory
			mkdir -p $BUILD_DIR_		fi

		cd $BUILD_DIR
		rm -rf $BUILD_DIR/p-$branch_dash
		# Download and unpack source files
		if [ "$use_src_folder" == 'true' ]; then
			[ "$DEBUG" ] && echo DEBUG: cp -rf "$SRC_DIR/" $BUILD_DIR/D-$branch_dash
			cp -rf "$SRC_DIR/" $BUILD_DIR/p-$branch_dash
		elif [ -d $SRC_DIR ]; then
			download_file $ARCHIVE_LINK '-' 'fresh' | tar xz
		fi

		mkdir -p $BUILD_DIR_usr/local/D		# Build web and move needed directories
		cd $BUILD_DIR/p-$branch_dash
		npm ci --ignore-scripts
		npm run build
		cp -rf bin func install web $BUILD_DIR_usr/local/D
		# Set permissions
		find $BUILD_DIR_usr/local/D-type f -exec chmod -x {} \;

		# Allow send email via /usr/local/web/inc/mail-wrapper.php via cli
		chmod +x $BUILD_DIR_usr/local/Deb/inc/mail-wrapper.php
		# Allow the executable to be executed
		chmod +x $BUILD_DIR_usr/local/Din/*
		find $BUILD_DIR_usr/local/Dnstall/ \( -name '*.sh' \) -exec chmod +x {} \;
		chmod -x $BUILD_DIR_usr/local/Dnstall/*.sh
		chown -R root:root $BUILD_DIR_		# Get Debian package files
		mkdir -p $BUILD_DIR_DEBIAN
		get_branch_file 'src/deb/control' "$BUILD_DIR_DEBIAN/control"
		if [ "$BUILD_ARCH" != "amd64" ]; then
			sed -i "s/amd64/${BUILD_ARCH}/g" "$BUILD_DIR_DEBIAN/control"
		fi
		get_branch_file 'src/deb/copyright' "$BUILD_DIR_DEBIAN/copyright"
		get_branch_file 'src/deb/preinst' "$BUILD_DIR_DEBIAN/preinst"
		get_branch_file 'src/deb/postinst' "$BUILD_DIR_DEBIAN/postinst"
		chmod +x $BUILD_DIR_DEBIAN/postinst
		chmod +x $BUILD_DIR_DEBIAN/preinst

		echo Building DEB
		dpkg-deb -Zxz --build $BUILD_DIR_$DEB_DIR

		# clear up the source folder
		if [ "$KEEPBUILD" != 'true' ]; then
			rm -r $BUILD_DIR_			rm -rf p-$branch_dash
		fi
		cd $BUILD_DIR/p-$branch_dash
	done
fi

#################################################################################
#
# Install Packages
#
#################################################################################

if [ "$install" = 'yes' ] || [ "$install" = 'y' ] || [ "$install" = 'true' ]; then
	# Install all available packages
	echo "Installing packages..."
	for i in $DEB_DIR/*.deb; do
		dpkg -i $i
		if [ $? -ne 0 ]; then
			exit 1
		fi
	done
	unset $answer
fi
