#!/bin/sh
# SCRIPTS_DIR/lib/notify.sh
# Function that sends a message using notify-send when in X, and using echo 
# when connected to a terminal

${source_notify-true} &&
    source_notify=false ||
    return 0

# TODO: use ck-list-sessions as well, merge with output.sh


_notify="$(command -v notify-send)"
show () {
    [ -z "${XAUTHORITY}" ] ||
	command sudo -u "${USER}" \
	    "${_notify}" --icon=${icon-dialog-info} ${notify_opts} "${@}"
    [ ! -t 1 -a -z "${LOG}" ] ||	# output if terminal, or logging
	echo "${message-MESSAGE}:" "${@}"
}

info () {
    ${verbose} || return 0
    local icon=${icon_info-${icon-dialog-info}} message=INFO
    show "${@}"
}

warn () {
    ${verbose} || return 0
    local icon=${icon_warn-dialog-warning} message=WARNING
    show "${@}" >&2
}

error () {
    local icon=${icon_error-dialog-error} message=ERROR
    show "${@}" >&2
}

cleanup () { :;}	# dummy function to be overwriten if required

die () {
    error "${@}"
    cleanup
    exit 1
}

send_message () {	# backwards compat
    case "${1}" in
	"-e")
	    shift
	    error "${@}"
	    ;;
	"-w")
	    shift
	    warn "${@}"
	    ;;
	"-i")
	    shift
	    info "${@}"
	    ;;
	*)
	    show "${@}"
	    ;;
    esac
}
