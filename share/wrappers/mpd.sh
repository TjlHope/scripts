#!/bin/sh
# SCRIPTS_DIR/lib/wrappers/mpc.sh
# Wrapper script to ensure mpd is started before launching clients.
# Note: doesn't work with program names containing spaces.
# Only checked to work on Gentoo with a line in sudoers:
#	%audio ALL = NOPASSWD: /etc/init.d/mpd

/etc/init.d/mpd --quiet status ||
    command sudo -n /etc/init.d/mpd --quiet start

[ -h "${0}" ] &&
    script_path="$(readlink -f "${0}")" ||
    script_path="${0}"
. "${script_path%/*}/../../lib/prog.sh"

exec $(get_prog $(command which -a "${0##*/}")) "${@}"
