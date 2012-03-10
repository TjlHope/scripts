#!/bin/sh
# SCRIPTS_DIR/lib/wrappers/get_iplayer.sh
# Wrapper script for get_iplayer, allows easy recording of series (using pvr) 
# and films, and easy watching of live tv.

# TODO:
#	Want to enable pvr to run in parallel, standard lockfile prevents this.  
#	Experiment with removing the lockfile, etc.

### check not already running
/usr/bin/pgrep "${0##*/}" >/dev/null && {
    echo "Error: $0 already running." >&2
    exit 1
}
### set up variables
[ -h "${0}" ] &&
    script_path="$(readlink -f "${0}")" ||
    script_path="${0}"
. "${script_path%/*}/../check_net.sh"

_iplayer="$(command -v "get_iplayer")"
LOG="${LOG:-/dev/null}"

case "${0##*/}" in

    "get_iplayer.series")

	pids=""
	for category in "${HOME}/.get_iplayer/pvr/"*
	do
	    [ -f "${category}" ] && {
		echo "No recordings set for PVR." >&2
		exit 2
	    }
	    (
		${_iplayer} --pvr "${category##*/}" "${@}" >${LOG} 2>&1 &&
		    echo "Finished category ${category##*/}." ||
		    echo "Category ${category##*/} failed." >&2
	    ) #& FIXME: lockfile pvr stops running in parallel
	    pids="${pids} ${!}"
	done
	wait ${pids}	# Wait for categories to finish before exiting.

	;;

    "get_iplayer.films")

	${_iplayer} --nosubdir --long --category=Film,Films \
	    --modes=flashhd,flashvhigh "${@}"

	;;

    "get_iplayer.live")

	${_iplayer} --type=livetv,liveradio \
	    --stream "${@}" --player="mplayer -cache 128 -" 

	;;

esac
