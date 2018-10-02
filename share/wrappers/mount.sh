#!/bin/sh
# shellcheck disable=1090
# SCRIPTS_DIR/share/wrappers/mount.sh

# source library scripts 
[ -h "$0" ] &&
    script_p="$(readlink -f "$0")" ||
    script_p="$0"
lib_d="${script_p%/*/*/*}/lib"
. "$lib_d/output.sh"
. "$lib_d/prog.sh"
. "$lib_d/status.sh"

case "${0##*/}" in

    "mount.e71")
	# check for directory
	[ -d "$HOME/E71" ] || mkdir "$HOME/E71" 
	inc_st
	# mount with bluetooth
	obexfs -b 00:25:CF:1F:EE:9B -- "$HOME/E71"
	inc_st
	;;

    "umount.e71")
	# unmount
	fusermount -u "$HOME/E71"
	inc_st
	# remove unneeded directory
	[ -d "$HOME/E71" ] && rmdir "$HOME/E71"
	inc_st
	;;

    "mount.iso")
	# find iso file
	case "$1" in
	    "-f"|"-i")  shift;;
	esac
        iso_file="$(readlink -f "$1")"
	# check it exists
	[ -f "$iso_file" ] || die "Invalid iso file: $iso_file"
	# define mount directory
	mount_dir="/media/cd-$(basename "$iso_file" .iso)"
	# check not already mounted
	grep -qe "/dev/loop[0-9][ 	]$mount_dir" </proc/mounts &&
            die "Already mounted: $mount_dir"
	# make directory if needed
	[ -d "$mount_dir" ] || mkdir "$mount_dir"
	mount -o loop,noatime,ro "$iso_file" "$mount_dir"
	;;

    "umount.iso")
	# find mount directory
	case "$1" in
	    "-a")       umount /media/cd-* && rmdir /media/cd-*; exit;;
	    "-d")       shift;;
	esac
        mount_dir="$1"
	# if none specified and only one - use that
	[ -z "$mount_dir" ] &&
	    [ "$(ls -d /media/cd-* 2>/dev/null | wc -l)" -eq 1 ] &&
	    mount_dir="$(ls -d /media/cd-*)"
	# check it exists
	[ -d "$mount_dir" ] || die "Invalid mount point: $mount_dir"
	# check if mounted
	grep -q "/dev/loop[0-9][ 	]${mount_dir%/}" </proc/mounts ||
	    die "Not mounted: $mount_dir"
	# unmount directory
	umount "$mount_dir"
	# remove unneeded directory
	[ -d "$mount_dir" ] && rmdir "$mount_dir"
	;;

    "mount.tmpfs")
	mount -t tmpfs -o size=224M,noauto,user,exec "$USER-tmpfs" "$1"
	;;

    "umount.tmpfs")
	umount "$1"
	;;
	
    "mount.media")
	while [ $# -gt 0 ] 
	do
	    {
		[ -b "$1" ] && {
		    dev="$1"
		} || [ -h "/dev/disk/by-label/$1" ] && {
		    dev="$(readlink -f "/dev/disk/by-label/$1")"
		}
	    } &&
		gvfs-mount -d "$dev" ||
		inc_st
	    shift
	done
	;;

    "umount.media")
	if [ $# -gt 0 ]
	then
	    while [ $# -gt 0 ]
	    do
		[ -d "$1" ] &&
		    gvfs-mount -u "$(readlink -f "$1")" ||
		    inc_st
		shift
	    done
	else
	    for mp in /media/* "/run/media/$USER/"*
	    do
		[ -d "$mp" ] && mountpoint -q "$mp" &&
		    gvfs-mount -u "$(readlink -f "$mp")" ||
		    inc_st
	    done
	fi
	;;

    *)
	echo "Invalid command: $0" >&2
	exit 1
	;;

esac
exit_st
