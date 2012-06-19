#!/bin/sh
# SCRIPTS_DIR/share/wrappers/emerge.sh
# TODO: Clean up

# source library scripts
[ -h "${0}" ] &&
    script_p="$(readlink -f "${0}")" ||
    script_p="${0}"
lib_d="${script_p%/*/*/*}/lib"
. "${lib_d}/status.sh"
. "${lib_d}/output.sh"

_emerge="$(command -v emerge)"

case "${0##*/}" in

    "emerge.update")

	# fetch first ops
	opts=""
	while [ ${#} -gt 0 ]
	do
	    case "${1}" in
		"--")
		    shift
		    break
		    ;;
		"-v"|"--verbose")
		    verbose=true
		    ops="${ops} ${1}"
		    ;;
		"-"*)
		    ops="${ops} ${1}"
		    ;;
		*)
		    pkgs="${pkgs} ${1}"
		    ;;
	    esac
	    shift
	done

	### Update
	ex_pkgs="cross-*/*"
	vcs_pkgs="$(command eix-installed -a 2>/dev/null \
	    | sed -ne 's:^\(.*/.*\)-9999\(-r[0-9]\+\)\?$:\1:p')"
	${_emerge} --ask --update --deep --newuse --with-bdeps=y --keep-going \
	    ${ex_pkgs:+--exclude ${ex_pkgs}} ${opts} \
	    ${pkgs:-@world ${vcs_pkgs}}
	comb_st
	info "	Emerge exit status: ${st_last}"

	# Catch errors and decide action
	echo "${ops}" | sed -ne "/\(\<-[^-]\?\S*p\|\<--pretend\>\)/q1" &&
	    [ ${st_last} -ne 130 ] && [ ${st_last} -ne 102 ] ||
	    exit ${st_total}

	# find necesary module updates
	update_mods="$(tac /var/log/emerge.log | sed -ne \
	    '0,/Started emerge on/ {
		s/.*>>> emerge.*\/\(python\|perl\|xorg-server\)-[0-9].*/\1/p
	    }')"

	# fetch second ops
	ops=""
	while [ ${#} -gt 0 ]
	do
	    [ "${1}" = "--" ] &&
		shift && break
	    ops="${ops} ${1} "
	    shift
	done

	### Remove uneccesary dependencies
	[ ${st_last} -eq 0 ] &&
	    ${_emerge} --quiet --depclean ${ops}
	comb_st
	info "	depclean exit status: ${st_last}"

	# Catch errors and decide action
	[ ${st_last} -ne 130 ] && [ ${st_last} -ne 102 ] || exit ${st_total}

	### Rebuild packages with broken link level dependencies
	${_revdep} ${@}		# rest of them for rebuild
	comb_st
	info "	revdep-rebuild exit status: ${st_last}"

	# Catch errors and decide action
	[ ${st_last} -ne 130 ] && [ ${st_last} -ne 102 ] || exit ${st_last}

	# can't be bothered to try and parse ops for these as well

	### Perform needed module updates
	for x in "${update_mods}"
	do
	    case "${x}" in
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
	    [ ${st_last} -ne 130 ] && [ ${st_last} -ne 102 ] || exit ${st_last}
	done

	### Clean uneeded tar.bz2's
	command eclean -d distfiles
	comb_st

	### Update eix index
	command eix-update --quiet
	comb_st

	;;

    "emerge.sync")
	#echo "Sync Portage..."
	#/usr/bin/emerge --sync --quiet
	#exit_status=$(( $exit_status + $res ))
	#echo "	Exit status: $res"

	#echo "Sync Layman..."
	#/usr/bin/layman --sync-all --quiet
	#exit_status=$(( $exit_status + $res ))
	##echo "	Exit status: $res"

	#echo "Update db"
	#/usr/sbin/eupdatedb --quiet

	eix-sync
	comb_st
	;;

    *)
	echo "Invalid command: ${0}" >&2
	exit 1
	;;

esac

exit
