#!/bin/bash

# Clean installation bootstrap for development purposes only
# Usage:    ./hst_bootstrap_install.sh [fork] [branch] [os]
# Example:  ./hst_bootstrap_install.sh p main ubuntu

# Define variables
fork=$1
branch=$2
os=$3

# Download specified installer and compiler
wget https://raw.githubusercontent.com/$fork/p/$branch/install/hst-install-$os.sh
wget https://raw.githubusercontent.com/$fork/p/$branch/src/hst_autocompile.sh

# Execute compiler and build core package
chmod +x hst_autocompile.sh
./hst_autocompile.sh --$branch no

# Execute Control Panel installer with default dummy options for testing
bash hst-install-$os.sh -f -y no -e admin@test.local -p P@ssw0rd -s $branch-$os.test.local --with-debs /tmp/D-src/debs
