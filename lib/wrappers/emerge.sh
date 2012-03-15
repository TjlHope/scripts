#!/bin/sh
# SCRIPTS_DIR/lib/wrappers/emerge.sh
# TODO: Clean up

res=0
exit_status=0

case "${0##*/}" in

    "emerge.update")

	# fetch first ops
	opts=""
	while [ -n "${1}" ]
	do
	    case "${1}" in
		"--")
		    shift
		    break
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
	/usr/bin/emerge --ask --update --deep --newuse --keep-going \
	    --exclude "cross-*/*" ${opts} \
	    ${pkgs:-@world}
	# update ops
	res=$? 
	#echo "	Exit status: $res"

	# Catch errors and decide action
	echo "$ops" | /bin/grep -e "-[^-	]*p" >/dev/null && exit $res
	[ $res -ne 130 ] && [ $res -ne 102 ] || exit $res
	#[ $res -eq 0 ] || exit $res
	exit_status=$(( ${exit_status} + ${res} ))

	# find necesary module updates
	update_mods="$(tac /var/log/emerge.log | sed -ne \
	    '0,/Started emerge on/ {
		s/.*>>> emerge.*\/\(python\|perl\|xorg-server\)-[0-9].*/\1/p
	    }')"

	# fetch second ops
	ops=""
	while [ -n "${1}" ]
	do
	    if [ "${1}" = "--" ]
	    then
		shift
		break
	    fi
	    ops="${ops} ${1} "
	    shift
	done

	### Remove uneccesary dependencies
	[ ${exit_status} -eq 0 ] &&
	    /usr/bin/emerge --quiet --depclean ${ops}		# depclean ops
	res=${?}
	#echo "	Exit status: $res"

	# Catch errors and decide action
	[ ${res} -ne 130 ] && [ ${res} -ne 102 ] || exit ${res}
	#[ $res -eq 0 ] || exit $res
	exit_status=$(( ${exit_status} + ${res} ))

	### Rebuild packages with broken link level dependencies
	/usr/bin/revdep-rebuild ${@}		# rest of them for rebuild
	res=${?}
	#echo "	Exit status: $res"

	# Catch errors and decide action
	[ ${res} -ne 130 ] && [ ${res} -ne 102 ] || exit ${res}
	#[ $res -eq 0 ] || exit $res
	exit_status=$(( ${exit_status} + ${res} ))

	# can't be bothered to try and parse ops for these as well

	### Perform needed module updates
	for x in "${update_mods}"
	do
	    case "${x}" in
		"python")
		    /usr/bin/eselect python update --python2
		    /usr/bin/eselect python update --python3
		    /usr/sbin/python-updater
		    res=${?}
		    ;;
		"perl")
		    /usr/sbin/perl-cleaner
		    res=${?}
		    ;;
		"xorg-server")
		    /usr/bin/emerge -1 "$(qlist -qCU xorg-drivers | sed -e \
			's:\([^ _]*\)_[^ _]*_\([^ _]*\):x11-drivers/xf86-\1-\2:g')"
		    res=${?}
		    ;;
	    esac
	    # Catch errors and decide action
	    [ ${res} -ne 130 ] && [ ${res} -ne 102 ] || exit ${res}
	    exit_status=$(( ${exit_status} + ${res} ))
	done

	### Clean uneeded tar.bz2's
	/usr/bin/eclean-dist -d

	### Update eix index
	/usr/bin/eix-update --quiet

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
	exit_status=${?}
	;;

    *)
	echo "Invalid command: ${0}" >&2
	exit 1
	;;

esac

exit ${exit_status}
