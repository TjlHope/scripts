#!/bin/sh
# SCRIPTS_DIR/lib/wrappers/pgrep.sh

#prog=${1:?No matching criteria specified.}
prog=${1}

[ -z "${@}" -o "${@#*-h}" != "${@}" ] && {
    echo "Usage: ${0} PATTERN" >&2
    exit
}

case "${0##*/}" in
    'lpgrep')
	exec /usr/bin/pgrep -l ${@}
	;;
    'cpgrep')
	for pid in $(/usr/bin/pgrep ${@})
	do
	    echo -n "${pid}: "
	    /bin/sed -e 's/\x0/ /g' /proc/${pid}/cmdline
	    echo
	done
	;;
    'fpgrep')
	exec /usr/bin/pgrep -lf ${@}
	;;
    *)
	echo "Invalid program: ${0}" 1>&2
	exit 1
esac

