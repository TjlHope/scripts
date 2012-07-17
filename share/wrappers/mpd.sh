#!/bin/sh
# SCRIPTS_DIR/share/wrappers/mpc.sh
# Wrapper script to ensure mpd is started before launching clients.
# Note: doesn't work with program names containing spaces.
# Only checked to work on Gentoo with a line in sudoers:
#	%audio ALL = NOPASSWD: /etc/init.d/mpd

[ -h "${0}" ] &&
    script_p="$(readlink -f "${0}")" ||
    script_p="${0}"
lib_d="${script_p%/*/*/*}/lib"
. "${lib_d}/output.sh"

mpd_service="${MPD_SERVICE-/etc/init.d/mpd --quiet}"

## Check, start, and assert MPD service
${mpd_service} status ||
    command sudo -n ${mpd_service} start
${mpd_service} status ||
    die "MPD service isn't started."

## run client with arguments

. "${lib_d}/prog.sh"

exec $(get_prog $(command which -a "${0##*/}")) "${@}"
