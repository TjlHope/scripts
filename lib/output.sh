#!/bin/sh
# SCRIPTS_DIR/lib/output.sh
# Functions to supplement just 'echo'ing messages.

${source_output-true} &&
    source_output=false ||
    return 0

show () {	# for notify.sh compat
    echo "MESSAGE:" "${@}"
}

info () {
    ${verbose} || return 0
    echo "INFO:" "${@}"
}

warn () {
    ${verbose} || return 0
    echo "WARNING:" "${@}" >&2
}

error () {
    echo "ERROR:" "${@}" >&2
}

cleanup () { :;}	# dummy function to be overwriten if required

die () {
    error "${@}"
    cleanup
    exit 1
}

