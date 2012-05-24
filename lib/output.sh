#!/bin/sh
# SCRIPTS_DIR/lib/echo.sh
# Functions to supplement just 'echo'ing messages.
# Use 'negative test' OR 'echo' so only non-zero return value is an error.

cleanup () {	# dummy function to be overwriten if required
    :
}

die () {
    [ ${verbose-0} -lt -1 ] ||
	echo "ERROR:" "${@}" >&2
    cleanup
    exit 1
}

warn () {
    [ ${verbose-0} -lt 0 ] ||
	echo "WARNING:" "${@}" >&2
}

info () {
    [ ${verbose-0} -le 0 ] ||
	echo "INFO:" "${@}"
}

