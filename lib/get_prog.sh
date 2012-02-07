#!/bin/sh
# SCRIPTS_DIR/lib/get_prog.sh
# Variable and function that uses `which` and `md5sum` to find the first
# program of the same name as the calling script.

# If which is currently an alias
which_alias="$(type 'which' | \
    sed -n 's:^which is .* alias.* \(for\|to\) [`'"'"']\?\(.*\)[`'"']\?$:\2:p")"
[ -n "${which_alias}" ] && {
    unalias which 2> /dev/null ||
	which_alias=''	# dash `type` reports 'tracked alias' after an unalias
}
# Get the binary path
which_bin="$(type 'which' | \
    sed -n 's:^which is.* \(\S\+\)$:\1:p')"
[ -n "${which_bin}" ] && type "${which_bin}" >/dev/null 2>&1 && {
    # Generate _which function (absolute path and no error output)
    eval "_which () { ${which_bin} \${@} 2> /dev/null ; }"
} || {
    echo "Cannot find 'which' binary." 1>&2
    exit 1
}
# Restore alias if it existed.
[ -n "${which_alias}" ] && {
    alias which="${which_alias}"
}
unset which_alias which_bin

get_prog () {
    # Get the first program in the arguments passed that the calling script is
    # named after. This assumes that the first result passed in is the script
    # itself, and uses the md5sum to ensure no duplicates.
    # Typical invocation is :
    #	get_prog $(_which "${0##*/}")
    script="${1}"
    script_md5="$(md5sum < "${script}")"
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

