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
		s/%20/\x20/g;		s/%21/\x21/g;
		s/%22/\x22/g;		s/%23/\x23/g;
		s/%24/\x24/g;		s/%25/\x25/g;
		s/%26/\x26/g;		s/%27/\x27/g;
		s/%28/\x28/g;		s/%29/\x29/g;
		s/%2[Aa]/\x2a/g;	s/%2[Bb]/\x2b/g;
		s/%2[Cc]/\x2c/g;	s/%2[Dd]/\x2d/g;
		s/%2[Ee]/\x2e/g;	s/%2[Ff]/\x2f/g;
		s/%30/\x30/g;		s/%31/\x31/g;
		s/%32/\x32/g;		s/%33/\x33/g;
		s/%34/\x34/g;		s/%35/\x35/g;
		s/%36/\x36/g;		s/%37/\x37/g;
		s/%38/\x38/g;		s/%39/\x39/g;
		s/%3[Aa]/\x3a/g;	s/%3[Bb]/\x3b/g;
		s/%3[Cc]/\x3c/g;	s/%3[Dd]/\x3d/g;
		s/%3[Ee]/\x3e/g;	s/%3[Ff]/\x3f/g;
		s/%40/\x40/g;		s/%41/\x41/g;
		s/%42/\x42/g;		s/%43/\x43/g;
		s/%44/\x44/g;		s/%45/\x45/g;
		s/%46/\x46/g;		s/%47/\x47/g;
		s/%48/\x48/g;		s/%49/\x49/g;
		s/%4[Aa]/\x4a/g;	s/%4[Bb]/\x4b/g;
		s/%4[Cc]/\x4c/g;	s/%4[Dd]/\x4d/g;
		s/%4[Ee]/\x4e/g;	s/%4[Ff]/\x4f/g;
		s/%50/\x50/g;		s/%51/\x51/g;
		s/%52/\x52/g;		s/%53/\x53/g;
		s/%54/\x54/g;		s/%55/\x55/g;
		s/%56/\x56/g;		s/%57/\x57/g;
		s/%58/\x58/g;		s/%59/\x59/g;
		s/%5[Aa]/\x5a/g;	s/%5[Bb]/\x5b/g;
		s/%5[Cc]/\x5c/g;	s/%5[Dd]/\x5d/g;
		s/%5[Ee]/\x5e/g;	s/%5[Ff]/\x5f/g;
		s/%60/\x60/g;		s/%61/\x61/g;
		s/%62/\x62/g;		s/%63/\x63/g;
		s/%64/\x64/g;		s/%65/\x65/g;
		s/%66/\x66/g;		s/%67/\x67/g;
		s/%68/\x68/g;		s/%69/\x69/g;
		s/%6[Aa]/\x6a/g;	s/%6[Bb]/\x6b/g;
		s/%6[Cc]/\x6c/g;	s/%6[Dd]/\x6d/g;
		s/%6[Ee]/\x6e/g;	s/%6[Ff]/\x6f/g;
		s/%70/\x70/g;		s/%71/\x71/g;
		s/%72/\x72/g;		s/%73/\x73/g;
		s/%74/\x74/g;		s/%75/\x75/g;
		s/%76/\x76/g;		s/%77/\x77/g;
		s/%78/\x78/g;		s/%79/\x79/g;
		s/%7[Aa]/\x7a/g;	s/%7[Bb]/\x7b/g;
		s/%7[Cc]/\x7c/g;	s/%7[Dd]/\x7d/g;
		s/%7[Ee]/\x7e/g;	s/%7[Ff]/\x7f/g;
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
