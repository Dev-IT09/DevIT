#!/bin/bash

# Control Panel upgrade script for target version 1.4.7

#######################################################################################
#######                      Place additional commands below.                   #######
#######################################################################################

if [ -n "$DB_PGA_ALIAS" ]; then
	$bin/v-change-sys-db-alias 'pga' "$DB_PGA_ALIAS"
fi
