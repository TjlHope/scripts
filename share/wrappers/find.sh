#!/bin/sh
# SCRIPTS_DIR/share/wrappers/find.sh

NL="
"

# Get Wrapper specific Opts:
unset icase
case "${0##*/}" in
    "find.iplayer")

	pattern="*[a-z]0[0-9a-z][0-9a-z][0-9a-z][0-9a-z][0-9a-z][0-9a-z]*.[mf][opl][v4]"
	while [ -n "$1" ]
	do
	    case "${a-$1}" in
		-*s*)
		    xfind="-printf$NL%k\\t%p\\n"
		    xsort="-k2$NL-t\	"
		    case "$1" in
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
		    pattern="${pattern%%.*}.partial*.${pattern##*.}"
		    ;;
		"-a")
		    pattern="*.${pattern##*.}"
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
        while [ $# -gt 0 ]
        do a="$1"; shift
            case "$a" in
                -i)     icase=i; continue;;
                -e)     pattern="$1"; shift;;
                '*'*)   pattern="$a";;
                *'*')   pattern="$a";;
                *)      pattern="*$a*";;
            esac
            break
        done
	;;

    *)
	echo "$0 is not a valid command" >&2
	exit 1
	;;

esac

# Get Major find options:
opts=""
while [ -n "$1" ]
do
    case "$1" in
	"-H"|"-L"|"-P"|"-O"?)
	    opts="$opts$NL$1"
	    ;;
	"-D")
	    opts="$opts$NL$1$NL$2"
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
while [ -n "$1" ]
do
    case "$1" in
	-*)
	    break
	    ;;
	*)
	    paths="$paths$NL$1"
	    ;;
    esac
    shift
done

# Execute find | sort
#echo "find $pre_opts $paths -${icase}name $name_regexp $@"
IFS="$NL"
exec find $opts $paths -${icase}name "$pattern" $xfind "$@" |
    sort $xsort

