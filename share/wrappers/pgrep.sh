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
    'lpgrep')   exec "$prog" -l "$@";;
    'cpgrep')   full='';;
    'fpgrep')   full='-f';;
    *)  echo "Invalid program: $0" >&2
	exit 1;;
esac

pids="$($prog $full "$@" 2>&1)" && {
    for pid in $pids
    do
        [ $pid -eq $$ ] ||
            sed -e 's/\x0/ /g' -e "s/^.*$/$pid &\n/" /proc/$pid/cmdline
    done
} || {
    [ -n "$pids" ] &&   # error message
        usage 1
}
