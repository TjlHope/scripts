#!/bin/sh
# SCRIPTS_DIR/lib/get_prog.sh
# Variable and function that uses `which` and `md5sum` to find the first
# program of the same name as the calling script.

which_bin="$(which "which" 2> /dev/null | /bin/sed 'N; s:.*\n\s*::')" || {
    echo "Cannot find 'which' binary." 1>&2
    exit 1
}

get_prog () {
    # Get the first program in the arguments passed that the calling script is
    # named after. This assumes that the first result passed in is the script
    # itself, and uses the md5sum to ensure no duplicates.
    # Typical invocation is :
    #	get_prog $(${which_bin} --all "${0##*/}" 2> /dev/null)
    script="${1}"
    script_md5="$(/usr/bin/md5sum < "${script}")"
    shift
    while [ -n "${1}" ] && [ "$(/usr/bin/md5sum < "${1}")" = "${script_md5}" ]
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

