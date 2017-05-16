#!/bin/sh
# SCRIPTS_DIR/share/wrappers/gentoo.sh
# Wrapper for gentoo style slotted scripts, with automatic environment sourcing
# TODO inspect whole path, not just in order...

case "$1" in ([+-][ex]) set "$1";; esac

name="${0##*/}"

# Source the conf file if it exists
[ -f "$HOME/.gentoo/${name}rc" ] && . "$HOME/.gentoo/${name}rc"

NL='
'
_ifs="$IFS"
IFS=":"
for path in ${PATH:-/bin:/usr/bin}
do  IFS="$_ifs"
    matches="$(ls -1v "${path%/}/$name"[-_.]* 2>/dev/null)" ||
        continue
    set -- "${matches##*$NL}" "$@"
    break       #^ last line is highest version
done

[ -n "$1" ] || {
    echo "Could not find '$name' in: $PATH" >&2
    exit 127
}

# clean up the environment :-)
unset name NL _ifs path matches
exec "$@"
