#!/bin/sh
# SCRIPTS_DIR/lib/wrappers/get_iplayer.sh
# Wrapper script for get_iplayer, allows easy recording of series (using pvr) 
# and films, and easy watching of live tv.

# TODO:
#	Want to enable pvr to run in parallel, standard lockfile prevents this.  
#	Experiment with removing the lockfile, etc.

### set up variables
[ -h "${0}" ] &&
    script_path="$(readlink -f "${0}")" ||
    script_path="${0}"
. "${script_path%/*}/../../lib/check_net.sh"

_iplayer="$(command -v "get_iplayer")"
log="${LOG-/dev/null}"

case "${0##*/}" in

    "get_iplayer.pvr")

	# FIXME: Hack
	#	pvr_lock stops pvr running in parallel, so remove it just 
	#	before running the pvr with a new category. Implement own 
	#	internal locking mechanism using cat_lock
	pvr_lock="${HOME}/.get_iplayer/pvr_lock"
	cat_lock="${HOME}/.get_iplayer/cat_lock"
	pids=""
	trap '[ -n "${pids}" ] && kill -INT ${pids}' INT # pass INT to subprocs
	for category in "${HOME}/.get_iplayer/pvr/"*
	do
	    [ -f "${category}" ] || {
		echo "No recordings set for PVR." >&2
		exit 2
	    }
	    (
		if [ ! -f "${pvr_lock}" ] || {	# not running pvr, or
			[ -f "${cat_lock}" ] && sed -ne \
			    "/^\s*${category##*/}\s*$/q1" "${cat_lock}" 
		    }	# ... not running this category
		then
		    # Lock category
		    echo "${category##*/}" >> "${cat_lock}"
		    [ -f "${pvr_lock}" ] &&	# remove generic pvr_lock file
			rm "${pvr_lock}"
		    # Run PVR for category.
		    ${_iplayer} --pvr "${category##*/}" "${@}" >"${log}" 2>&1 &&
			echo "Finished category ${category##*/}." ||
			echo "Failed to record category ${category##*/}." >&2
		    # Unlock category
		    sed -i -e "/^\s*${category##*/}\s*$/d" "${cat_lock}"
		    num=$(wc -l <"${cat_lock}" 2>"${log}")
		    [ ${num:-1} -gt 0 ] ||
			rm "${cat_lock}"	# remove cat_lock file if empty
		else
		    echo "Cannot record category ${category##*/}," \
			"PVR already running." >&2
		fi
	    ) &
	    pids="${pids} ${!}"
	done
	wait ${pids}	# Wait for categories to finish before exiting.
	trap - INT

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
