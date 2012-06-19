#!/bin/sh
# SCRIPTS_DIR/share/wrappers/bizip2.sh
# FIXME: unfinished

# defaults
size="1G"
bytes=1073741824
force=0

size2bytes () {
    sz="$(echo ${1} | sed -ne \
	    's:\([0-9]\+\)\([cwbKMGTPEZY]\?\)\([Bi]\?\):\1|\2|\3:p')"
    [ -n "${sz##*|}" ] &&
	mul=1000 ||
	mul=1024
    sz=${sz%|*}
    case "${sz#*|}" in
	'c')
	    mul=1;;
	'w')
	    mul=2;;
	'b')
	    mul=512;;
	'k')
	    mul=${mul};;
	'M')
	    mul=$((${mul}*${mul}));;
	'G')
	    mul=$((${mul}*${mul}*${mul}));;
	'T')
	    mul=$((${mul}*${mul}*${mul}*${mul}));;
	'P')
	    mul=$((${mul}*${mul}*${mul}*${mul}*${mul}));;
	'E')
	    mul=$((${mul}*${mul}*${mul}*${mul}*${mul}*${mul}));;
	'Z')
	    mul=$((${mul}*${mul}*${mul}*${mul}*${mul}*${mul}*${mul}));;
	'Y')
	    mul=$((${mul}*${mul}*${mul}*${mul}*${mul}*${mul}*${mul}*${mul}));;
    esac
    return $((${sz%%|*}*${mul}))

# Find the action from the name
case "${0}" in
    "bzsplit")
	# Split file into pieces and compress.
	action='-zc'
	;;
    "bzjoin")
	# Decompress and join files split with bzjoin.
	action='-dc'
	;;
esac

# Parse the rest of the command line
while [ -n "${1}" ]
do
    if [ "${1%%-*}" = '' ]
    then
	case "${1}" in
	    "-b"|"--block"|"--block-size")
		size="${2}"
		shift
		;;
	    "-f"|"--force")
		force=1
		opts="${opts# } ${1}"
		;;
	    "-o"|"--output"|"--outfile")
		file_name="${2}"
		shift
		;;
	    *)
		opts="${opts# } ${1}"
		;;
	esac
    else
	files="${files# } ${1}"
    fi
    shift
done

# Process file names
