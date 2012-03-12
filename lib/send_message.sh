#!/bin/sh
# SCRIPTS_DIR/lib/send_message.sh
# Function that sends a message using notify-send if in X, echo otherwise.
# TODO: use ck-list-sessions as well

send_message () {
    case "${1}" in
	"-e")
	    sm_icon="${icon_error-dialog-error}"
	    pre_message="Error:"
	    shift
	    ;;
	"-w")
	    [ ${verbose-0} -gt 0 ] || return 0
	    sm_icon="${icon_warning-dialog-warning}"
	    pre_message="Warning:"
	    shift
	    ;;
	"-i")
	    [ ${verbose-0} -gt 0 ] || return 0
	    shift
	    ;;
    esac
    [ -n "${XAUTHORITY}" ] &&
	/usr/bin/sudo -u "${USER}" \
	    /usr/bin/notify-send --icon=${sm_icon-${icon-dialog-info}} \
		${notify_opts} "${@}" ||
	echo ${pre_message} "${@}"
}

