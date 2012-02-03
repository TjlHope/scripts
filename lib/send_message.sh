#!/bin/sh
# SCRIPTS_DIR/lib/send_message.sh
# Function that sends a message using notify-send if in X, echo otherwise.

send_message () {
    pre_message=""
    sm_icon=${icon-dialog-info}
    case "${1}" in
	"-e")
	    sm_icon="dialog-error"
	    pre_message="Error: "
	    shift
	    ;;
	"-w")
	    [ ${verbose-0} -gt 0 ] || return 0
	    sm_icon="dialog-warning"
	    pre_message="Warning: "
	    shift
	    ;;
	"-i")
	    [ ${verbose-0} -gt 0 ] || return 0
	    shift
	    ;;
    esac
    #for w in "$@"
    #do
	#echo $w
    #done
    #echo "-------"
    [ -n "${XAUTHORITY}" ] &&
	/usr/bin/sudo -u "${USER}" \
	    /usr/bin/notify-send --icon=${sm_icon} \
		${notify_opts} "${@}" ||
	echo ${pre_message} "${@}"
}

