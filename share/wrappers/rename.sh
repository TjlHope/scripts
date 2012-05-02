#!/bin/bash
# SCRIPTS_DIR/lib/wrappers/rename.sh
# TODO: Need to rewrite without bash arrays
#	Maybe only allow options at start, parse them and $0 to store operation 
#	as variables (put the case outside the for loop and store the sed
#	script as a variable). Then iterate over the rest of the files using
#	shift and while [ -n "$1" ] (a la find wrapper)

command_name="${0##*/}"
declare -a files

# defaults for commands
ask=0
verbose=0
perform='y' 

i=0
### parse command line options
while [ -n "${1}" ]
do
    case "${1}" in
	"-a"|"--ask")
	    ask=1;
	    verbose=1
	    ;;
	"-p"|"--pret"|"--pretend")
	    perform='n';
	    verbose=1
	    ;;
	"-v"|"--verb"|"--verbose")
	    verbose=1
	    ;;
	"-h"|"-?"|"--help")
	    echo "Usage: ${0} [options] [files]"
	    echo
	    echo "OPTIONS"
	    echo "	-v, --verb, --verbose"
	    echo "		Verbosely output renames being performed."
	    echo "	-p, --pret, --pretend"
	    echo "		Do not perform rename (implies --verbose)."
	    echo "	-a, --ask"
	    echo "		Ask before performing renames."
	    echo
	    exit 0
	    ;;
	*)
	    [ -f "${1}" ] && {
		files[${i}]="${1}"
		i=$(( ${i} + 1 )) 
	    } ||
		echo "Invalid File: ${1}" >&2
	    ;;
    esac
    shift
done

# Get sed expresion string for name substitution
case "${command_name}" in
    "rename.spaces")
	sed_expr='/ / s/ /_/gp'
	;;
    "rename.html")
	sed_expr='/%[0-9a-fA-F]\{2\}/ {
	    s/%20/ /g
	    s/%21/!/g
	    s/%22/\\"/g
	    s/%23/#/g
	    s/%24/\\\$/g
	    s/%25/%/g
	    s/%26/\\&/g
	    s/%27/\\\"/g
	    s/%28/(/g
	    s/%29/)/g
	    s/%2[Aa]/\\*/g
	    s/%2[Bb]/+/g
	    s/%2[Cc]/,/g
	    s/%2[Dd]/-/g
	    s/%2[Ee]/\\./g
	    s/%2[Ff]/\\\//g
	    s/%3[Aa]/\:/g
	    s/%3[Bb]/\;/g
	    s/%3[Cc]/\</g
	    s/%3[Dd]/\=/g
	    s/%3[Ee]/\>/g
	    s/%3[Ff]/?/g
	    s/%3[Ff]/?/g
	    p
	}'
	;;
    "rename.iplayer")
	sed_expr='/[a-z]0.\{6\}.*\.m[op][v4]$/ {
	    s/\(_-\)*_[a-z]0.\{6\}\(_default\)\?//p
	}'
	;;
    "move.iplayer")
	sed_expr='\:\([^/]\+\)/\(Series_[0-9A-Z]\+/\)\?\1_\(Series_[0-9A-Z]\+_\)\?-_.*\.[mf][opl][v4]$: {
	    s:\([^/]\+\)/\(Series_[0-9A-Z]\+/\)\?\1_\(Series_[0-9A-Z]\+\)\?_\?-_\(.*\.[mf][opl][v4]\)$:\1/\3/\4:p
	}'
	;;
    *)
	echo "Invalid command; ${0}" >&2
	exit 1
	;;
esac

# Process files
for file_name in "${files[@]}"
do
    # Get new name for file
    new_name="$(echo "${file_name}" | sed -ne "${sed_expr}")"

    # If substitution fails go on to next name
    [ -n "${new_name}" ] || continue

    # Output conversion if being verbose
    [ ${verbose} -gt 0 ] &&
	echo "${file_name} -> ${new_name}"

    # If confirmation required...
    # ... init
    [ ${ask} -gt 0 ] &&
	perform=''
    # ... prompt and check
    while [[ ! "${perform}" =~ [yY](es)?|[nN]o? ]]
    do
	[ "${perform}" ] && echo "Invalid answer: ${perform}"
	echo -n "Perform rename? (y/n) "
	read perform
    done

    # Perform operation if required.
    [[ "${perform}" =~ [yY](es)? ]] && {
	[ "${new_name%/*}" != "${new_name}" ] && {	# only need dir if path
	    [ -d ${new_name%/*} ] ||
		mkdir ${new_name%/*}			# needing -p => error
	}
	mv -i "${file_name}" "${new_name}"
    }

done
