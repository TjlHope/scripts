#!/bin/sh
# SCRIPTS_DIR/lib/wrappers/mpc.sh
# Wrapper script to ensure mpd is started before launching clients.
# Note: doesn't work with program names containing spaces.
# Only checked to work on Gentoo with a line in sudoers:
#	%audio ALL = NOPASSWD: /etc/init.d/mpd

/etc/init.d/mpd --quiet status > /dev/null ||
    /usr/bin/sudo /etc/init.d/mpd --quiet start

[ -h "${0}" ] &&
    script_path="$(/bin/readlink -f "${0}")" ||
    script_path="${0}"
. "${script_path%/*}/../../lib/get_prog.sh"

exec $(get_prog $(_which --all "${0##*/}")) ${@}
