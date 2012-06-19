#!/bin/sh
# SCRIPTS_DIR/bin/ic_keepalive.sh
# Script to ping the current gateway with a single packet
# Used with cron to prevent network connection timeouts
# @author: TjlH

# Make sure we're on IC network or eduroam
if [ -x "/usr/bin/wicd-cli" ]
then
    # If we find valid essid, don't perform the exit 
    wicd-cli -yd | /bin/sed -ne '/Essid:\s\+\(Imperial-WPA\|eduroam\)/q1' &&
	exit 2
elif [ -x "/usr/bin/nm-tool" ]
then
    nm-tool | sed -ne '/\s\+\*\(Imperial-WPA\|eduroam\)/q1' &&
	exit 2
else
    echo "Warning: Could not find wicd-cli or nm-tool." 1>&2
    echo "	Performing ping anyway." 1>&2
fi

# Find current gateway
gateway="$(/sbin/route -n | /bin/sed -ne 's:^0.0.0.0\s\+\([0-9\.]\+\).*:\1:p')"
# Ping it once
/bin/ping -c1 -q ${gateway} >/dev/null 2>&1 ||
    echo "Error: Could not ping gateway." 1>&2

date "+[%F %T] pinged ${gateway} with 1 packet." >> /home/tom/.log/keepalive.log
