#!/bin/sh
# SCRIPTS_DIR/share/wrappers/pgrep.sh

prog="$(command -v pgrep)" || {
    echo "Error: Cannot find 'pgrep' executable."
    exit 1
}

usage () {
    echo "Usage: $0 PATTERN" >&2
    exit $1
}

case "$*" in
    '')		usage 1;;
    *[$IFS]-h*)	usage;;
esac

case "${0##*/}" in
    'lpgrep')
	exec $prog -l "$@"
	;;
    'cpgrep')
        pids="$($prog "$@" 2>&1)" || {
            [ -n "$pids" ] &&   # error message
                usage 1 ||
                exit 1
        }
	for pid in $pids
	do
	    echo -n "$pid: "
	    sed -e 's/\x0/ /g' /proc/$pid/cmdline
	    echo
	done
	;;
    'fpgrep')
	exec $prog -lf "$@"
	;;
    *)
	echo "Invalid program: $0" >&2
	exit 1
esac

