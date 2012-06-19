#!/bin/sh
# SCRIPTS_DIR/share/wrappers/pgrep.sh

prog="$(command -v pgrep)"

[ -z "${*}" -o "${*#*-h}" != "${*}" ] && {
    echo "Usage: ${0} PATTERN" >&2
    exit
}

case "${0##*/}" in
    'lpgrep')
	exec ${prog} -l "${@}"
	;;
    'cpgrep')
	for pid in $(${prog} "${@}")
	do
	    echo -n "${pid}: "
	    sed -e 's/\x0/ /g' /proc/${pid}/cmdline
	    echo
	done
	;;
    'fpgrep')
	exec ${prog} -lf "${@}"
	;;
    *)
	echo "Invalid program: ${0}" 1>&2
	exit 1
esac

