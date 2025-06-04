#!/bin/bash

for file in /usr/local/bin/*; do
	echo "$file" >> ~/cli_help.txt
	[ -f "$file" ] && [ -x "$file" ] && "$file" >> ~/cli_help.txt
done

sed -i 's\/usr/local/bin/\\' ~/Dli_help.txt
