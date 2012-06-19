#!/bin/sh
# SCRIPTS_DIR/share/wrappers/grep.sh

[ -z "${1}" -o "${1}" = '-h' ] && {
    echo "Usage: $0 PATTERN [PATH[ PATH[ ...]]]"
    exit
}

# prog specific options
case "${0##*/}" in
    lgrep)
	sopts="-A 2 -B 2"
	;;
    rgrep)
	sopts="-R"
	path_def='./'
	;;
esac

# split opts and args
while [ -n "${1}" ]
do
    case "${1}" in
	-*e)
	    [ "${1%e}" = '-' ] ||
		opts="${opts} ${1%e} "
	    shift
	    patts="${patts}-e ${1} "
	    ;;
	-*)
	    opts="${opts}${1} "
	    ;;
	*)
	    paths="${paths}${1}	"
	    ;;
    esac
    shift
done

# check for patt
[ -z "${patts}" ] && {
    patt="${paths%%	*}"
    paths="${paths#*	}"
}

exec grep --color=auto ${sopts} ${opts} "${patt}" ${patts} ${paths:-${path_def}}
