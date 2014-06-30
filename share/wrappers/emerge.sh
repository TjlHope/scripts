#!/bin/sh
# SCRIPTS_DIR/share/wrappers/emerge.sh
# TODO: Clean up

# source library scripts
[ -h "$0" ] &&
    script_p="$(readlink -f "$0")" ||
    script_p="$0"
lib_d="${script_p%/*/*/*}/lib"
. "$lib_d/status.sh"
. "$lib_d/output.sh"
. "$lib_d/prog.sh"

_emerge="$(first_cmd emerge)"

case "${0##*/}" in

    "emerge.update")

	_revdep="$(first_cmd revdep-rebuild)"
	_clean="$(first_cmd "eclean -d distfiles")"
	_update="$(first_cmd eix-update eupdatedb)"

	# fetch first ops
	ops=""
	while [ $# -gt 0 ]
	do
	    case "$1" in
		"--")
		    shift
		    break
		    ;;
		"-v"|"--verbose")
		    verbose=true
		    ops="$ops $1"
		    ;;
		"-"*)
		    ops="$ops $1"
		    ;;
		*)
		    pkgs="$pkgs $1"
		    ;;
	    esac
	    shift
	done

	### Update
	excludes="--exclude=cross-*/*"
	vcs_pkgs="$(command eix-installed -a 2>/dev/null \
	    | sed -ne 's:^\(.*/.*\)-9999\(-r[0-9]\+\)\?$:\1:p')"
	"$_emerge" --ask --keep-going --update --newuse --deep --with-bdeps=y \
	    $excludes $ops \
	    ${pkgs:-@world --oneshot $vcs_pkgs}
	comb_st
	info "	Emerge exit status: $_st_last"

	# Catch errors and decide action
	echo "$ops" | sed -ne "/\(\<-[^-]\?\S*p\|\<--pretend\>\)/q1" &&
	    [ $_st_last -ne 130 ] && [ $_st_last -ne 102 ] ||
	    exit $_st_total

	# find necesary module updates
	update_mods="$(tac /var/log/emerge.log | sed -ne \
	    '0,/Started emerge on/ {
		s/.*>>> emerge.*\/\(python\|perl\|xorg-server\)-[0-9].*/\1/p
	    }')"

	# fetch second ops
	ops=""
	while [ $# -gt 0 ]
	do
	    [ "$1" = "--" ] &&
		shift && break
	    ops="$ops $1 "
	    shift
	done

	### Remove uneccesary dependencies
	[ $_st_last -eq 0 ] &&
	    "$_emerge" --quiet --depclean $ops
	comb_st
	info "	depclean exit status: $_st_last"

	# Catch errors and decide action
	[ $_st_last -ne 130 ] && [ $_st_last -ne 102 ] || exit $_st_total

	### Rebuild packages with broken link level dependencies
	$_revdep "$@"		# rest of them for rebuild
	comb_st
	info "	revdep-rebuild exit status: $_st_last"

	# Catch errors and decide action
	[ $_st_last -ne 130 ] && [ $_st_last -ne 102 ] || exit $_st_last

	# can't be bothered to try and parse ops for these as well

	### Perform needed module updates
	for x in "$update_mods"
	do
	    case "$x" in
		"python")
		    command eselect python update --python2
		    command eselect python update --python3
		    command python-updater
		    ;;
		"perl")
		    command perl-cleaner
		    ;;
		"xorg-server")
		    command emerge -1 "$(qlist -qCU xorg-drivers | sed -e \
			's:\([^ _]*\)_[^ _]*_\([^ _]*\):x11-drivers/xf86-\1-\2:g')"
		    ;;
	    esac
	    comb_st
	    # Catch errors and decide action
	    [ $_st_last -ne 130 ] && [ $_st_last -ne 102 ] || exit $_st_last
	done

	### Clean uneeded tar.bz2's
	$_clean
	comb_st

	### Update eix index
	$_update -q
	comb_st

	;;

    "emerge.sync")

	_update="$(first_cmd eix-sync eupdatedb)"
	_layman="$(first_cmd layman)"

	if [ -n "${_update##*sync*}" ]
	then

	    #echo "Sync Portage..."
	    $_emerge -q --sync
	    comb_st

	    #echo "Sync Layman..."
	    $_layman -q --sync-all
	    comb_st

	fi

	#echo "Update db"
	$_update -q
	comb_st

	;;

    *)
	echo "Invalid command: $0" >&2
	false
	;;

esac

exit
