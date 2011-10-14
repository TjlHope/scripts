#!/bin/bash
# TODO: Need to rewrite without bash arrays
#	Maybe only allow options at start, parse them and $0 to store operation 
#	as variables (put the the case outside the for loop and store the sed
#	script as a variable). Then iterate over the rest of the files using
#	shift and while [ -n "$1" ] (ala find.wrapper)

command_name="$(/bin/basename $0)"
declare -a files

ask=0
verbose=0
perform='y' 

i=0
### parse command line options
while [ "$1" ]
do
    case "$1" in
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
	    echo "Usage: $0 [options] [files]"
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
	    [ -f "$1" ] && {
		files[$i]="$1"
		(( i+=1 )) 
	    } ||
		echo "Invalid File: $1" >&2
	    ;;
    esac
    shift
done

for file_name in "${files[@]}"
do
    case "$command_name" in
	"rename.spaces")
	    new_name="$(echo "$file_name" | /bin/sed -ne '/ / s/ /_/gp')"
	    ;;
	"rename.html")
	    new_name="$(echo "$file_name" | /bin/sed -ne '/%[0-9a-fA-F]\{2\}/ {
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
						s/%2[Bb]/\\,/g
						s/%2[Cc]/+/g
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
					    }')"
	    ;;
	"rename.iplayer")
	    new_name="$(echo "$file_name" | \
			    /bin/sed -ne '/[a-z]0.\{6\}.*\.m[op][v4]$/ {
					    s/\(_-\)*_[a-z]0.\{6\}_default//p
					}')"
	    ;;
	*)
	    echo "Invalid command; $0" >&2
	    exit 1
	    ;;
    esac

    [ "$new_name" ] || continue

    [ $verbose -gt 0 ] &&
	echo "$file_name -> $new_name"

    [ $ask -gt 0 ] &&
	perform=''

    while [[ ! "$perform" =~ [yY](es)?|[nN]o? ]]
    do
	[ "$perform" ] && echo "Invalid answer: $perform"
	echo -n "Perform rename? (y/n) "
	read perform
    done

    [[ "$perform" =~ [yY](es)? ]] &&
	mv "$file_name" "$new_name"

done
