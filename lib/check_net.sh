#!/bin/sh
# SCRIPTS_DIR/lib/check_net.sh
# Function that uses ping to test the internet connection.

_ping="$(command -v ping)" || {
    echo "Cannot find 'ping'" >&2
    kill -INT $$
}

check_net () {
    if [ $# -gt 0 ]
    then	# each arg is a address to check
	while [ -n "$1" ]
	do
	    ${_ping} ${_ping_args- -c 1 -W 1} $1 &&
		return 0 ||
		shift
	done
	return 1
    else	# Try this defaut list
	check_net "bbc.co.uk" "google.co.uk" "amazon.co.uk" \
	    "google.com" "amazon.com"
    fi
}

