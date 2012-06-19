#!/bin/sh
# SCRIPTS_DIR/lib/check_type.sh
# Functions to check the type of data.

${source_check_type-true} &&
    source_check_type=false ||
    return 0

# TODO: add more :)

check_int () {
    [ $1 -eq 0 -o $1 -ne 0 ] 2>/dev/null ||	# failure returns 2
	return 1
}

# Implemented by modifying the IFS variable local to each function. This 
# enables all characters valid to the type check to be ignored, and if anything 
# else is found then we can return FALSE.
# The use of ${@} means that multiple input values can be checked at once.
check_chars () {
    local IFS="${IFS}${1}"	# first argument are the chars to check
    shift			# ... get rid of them
    for x in ${@}		# test the rest of the arguments
    do
	[ -z "$x" ] ||
	    return 1
    done
}

