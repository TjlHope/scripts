#!/bin/sh
# SCRIPTS_DIR/lib/prog.sh
# Functions to ease the finding of the wanted program.


# Variable and function that uses `which` and `md5sum` to find the first
# program of the same name as the calling script.

_which='command which'	# backwards compatability

get_prog () {
    # Get the first program in the arguments passed that the calling script is
    # named after. This assumes that the first result passed in is the script
    # itself, and uses the md5sum to ensure no duplicates.
    # Typical invocation is :
    #	get_prog $(command which -a "${0##*/}")
    local script="${1}"
    local script_md5="$(md5sum < "${script}")"
    shift
    while [ -n "${1}" ] && [ "$(md5sum < "${1}")" = "${script_md5}" ]
    do
	shift
    done
    [ -n "${1}" ] && {
	echo "${1}"
	return 0
    } || {
	echo "Cannot find program '${script}' refers to." 1>&2
	return 1
    }
}


# Function to find the first valid program in the argument list, and return 
# it's full path.

first_cmd () {
    local cmd
    while [ -n "${1}" ]
    do
	cmd="$(command -v "${1}")" && {
	    echo "${cmd}"
	    return 0
	}
	shift
    done
    echo 'false'	# in case return value isn't checked
    return 1
}

