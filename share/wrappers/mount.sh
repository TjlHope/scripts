#!/bin/sh
# SCRIPTS_DIR/share/wrappers/mount.sh

# source library scripts 
[ -h "${0}" ] &&
    script_p="$(readlink -f "${0}")" ||
    script_p="${0}"
lib_d="${script_p%/*/*/*}/lib"
. "${lib_d}/prog.sh"
. "${lib_d}/status.sh"

case "${0##*/}" in

    "mount.e71")
	# check for directory
	[ -d ${HOME}/E71 ] || /bin/mkdir "${HOME}/E71" 
	inc_st
	# mount with bluetooth
	obexfs -b 00:25:CF:1F:EE:9B -- "${HOME}/E71"
	inc_st
	;;

    "umount.e71")
	# unmount
	/usr/bin/fusermount -u "${HOME}/E71"
	inc_st
	# remove unneeded directory
	[ -d ${HOME}/E71 ] && /bin/rmdir "${HOME}/E71"
	inc_st
	;;

    "mount.iso")
	# find iso file
	case "$1" in
	    "-f"|"-i")
		iso_file="$2"
		;;
	    *)
		iso_file="$1"
		;;
	esac
	# check it exists
	[ -f $iso_file ] || {
	    echo "Error: Provide valid iso file" >&2
	    exit 1
	}
	# define mount directory
	mount_dir="/media/cd-$(basename "$iso_file" .iso)"
	# check not already mounted
	/bin/grep -e "/dev/loop[0-9][ 	]$mount_dir" < /proc/mounts &> /dev/null &&
	    {
		echo "Error: $mount_dir already mounted" >&2
		exit 1
	    }
	# make directory if needed
	[ -d "$mount_dir" ] || mkdir "$mount_dir"
	/bin/mount -o loop,noatime,ro "$iso_file" "$mount_dir"
	;;

    "umount.iso")
	# find mount directory
	case "$1" in
	    "-a")
		# allow 'all' switch
		/bin/umount /media/cd-*
		exit
		;;
	    "-d")
		mount_dir="$2"
		;;
	    *)
		mount_dir="$1"
	esac
	# if none specified and only one - use that
	[ -z "$mount_dir" ] && [ $(ls -d /media/cd-* 2>/dev/null | wc -l) -eq 1 ] &&
	    mount_dir="$(ls -d /media/cd-*)"
	# check it exists
	[ -d $mount_dir ] || {
	    echo "Error: Provide valid mount point" >&2
	    exit 1
	}
	# check if mounted
	/bin/grep -e "/dev/loop[0-9][ 	]$mount_dir" < /proc/mounts &> /dev/null || {
	    echo "Error: $mount_dir is not mounted" >&2
	    exit 1
	}
	# unmount directory
	/bin/umount "$mount_dir"
	# remove unneeded directory
	[ -d "$mount_dir" ] && /bin/rmdir "$mount_dir"
	;;

    "mount.tmpfs")
	/bin/mount -t tmpfs -o size=224M,noauto,user,exec "$USER-tmpfs" "$1"
	;;

    "umount.tmpfs")
	/bin/umount "$1"
	;;
	
    "mount.media")
	while [ ${#} -gt 0 ] 
	do
	    {
		[ -b "${1}" ] && {
		    dev="${1}"
		} || [ -h "/dev/disk/by-label/${1}" ] && {
		    dev="$(readlink -f "/dev/disk/by-label/${1}")"
		}
	    } &&
		gvfs-mount -d "${dev}" ||
		inc_st
	    shift
	done
	;;

    "umount.media")
	if [ ${#} -gt 0 ]
	then
	    while [ ${#} -gt 0 ]
	    do
		[ -d "${1}" ] &&
		    gvfs-mount -u "${1}" ||
		    inc_st
		shift
	    done
	else
	    for mp in /media/* /run/media/${USER}/*
	    do
		[ -d "${mp}" ] &&
		    gvfs-mount -u "$mp" ||
		    inc_st
	    done
	fi
	;;

    *)
	echo "Invalid command: $0" >&2
	exit 1
	;;

esac
