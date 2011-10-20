#!/bin/sh

#prog=${1:?No matching criteria specified.}
prog=${1}

[ -z ${prog} -o ${prog} = '-h' ] && {
    echo "Usage: $0 {PATTERN}" >&2
    exit
}

case "$(basename ${0})" in
    'lpgrep')
	/usr/bin/pgrep -l ${prog}
	;;
    'cpgrep')
	for pid in $(/usr/bin/pgrep ${prog})
	do
	    echo -n "${pid}: "
	    /bin/sed -e 's/\x0/ /g' /proc/${pid}/cmdline
	    echo
	done
	;;
    *)
	echo "Invalid program: ${0}" 1>&2
	exit 1
esac

