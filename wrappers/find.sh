#!/bin/sh

# Get Wrapper specific Opts:
case "$(/bin/basename $0)" in
    "find.iplayer")

	pattern="*[a-z]0[0-9]*.[mf][opl][v4]"
	while [ -n "${1}" ]
	do
	    case "${a-${1}}" in
		-*s*)
		    xfind='-printf %k\t%p\n'
		    xsort="-k 2 -t \	"
		    case "${1}" in
			-s)
			    shift;;
			-s?)
			    a="-${1#-s}";;
			-?s)
			    a="${1%s}";;
		    esac
		    continue
		    ;;
		"-n")
		    ;;
		"-p")
		    pattern="*partial*.[mf][opl][v4]"
		    ;;
		"-a")
		    pattern="*.[mf][opl][v4]"
		    ;;
		*)
		    break
		    ;;
	    esac
	    unset a
	    shift
	done
	;;

    "find.swp")
	pattern='.*.sw?'
	;;

    "rfind")
	pattern="*${1}*"
	shift
	;;

    *)
	echo "${0} is not a valid command" >&2
	exit 1
	;;

esac

# Get Major find options:
opts=""
while [ -n "${1}" ]
do
    case "${1}" in
	"-H"|"-L"|"-P"|"-O"?)
	    opts="${opts} ${1}"
	    ;;
	"-D")
	    opts="${opts} ${1} ${2}"
	    shift
	    ;;
	*)
	    break
	    ;;
    esac
    shift
done

# Get find paths:
paths=""
while [ -n "${1}" ]
do
    case "${1}" in
	-*)
	    break
	    ;;
	*)
	    paths="${paths} ${1}"
	    ;;
    esac
    shift
done

# Execute find | sort
#echo "find $pre_opts $paths -name $name_regexp $@" 
exec /usr/bin/find ${opts} ${paths} -name "${pattern}" ${xfind} ${@} \
    | /bin/sort ${xsort}

