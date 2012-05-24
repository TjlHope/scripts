#!/bin/sh
# SCRIPTS_DIR/lib/send_message.sh
# Function that sends a message using notify-send if in X, echo otherwise.
# TODO: use ck-list-sessions as well

send_message () {
    case "${1}" in
	"-e")
	    local sm_icon="${icon_error-dialog-error}"
	    local pre_message="Error:"
	    shift
	    ;;
	"-w")
	    ${verbose} || return 0
	    local sm_icon="${icon_warning-dialog-warning}"
	    local pre_message="Warning:"
	    shift
	    ;;
	"-i")
	    ${verbose} || return 0
	    local pre_message="Info:"
	    shift
	    ;;
    esac
    [ -n "${XAUTHORITY}" ] &&
	command sudo -u "${USER}" \
	    notify-send --icon=${sm_icon-${icon-dialog-info}} \
		${notify_opts} "${@}" ||
	echo ${pre_message} "${@}"
}

cleanup () {	# dummy function to be overwriten if required
    :
}

die () {
    send_message -e "${@}"
    cleanup
    exit 1
}

