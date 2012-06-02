#!/bin/sh
# SCRIPTS_DIR/lib/wrappers/xfconf.sh
# Small script to access the xfconf utility, personally used from changing
# compositing and theme.

prog="$(command -v xfconf-query)"

name="${0##*/}"

# Extract channel and property from command name
channel="${name%%.*}"
[ ${name#*.} = ${name##*.} ] &&
    property="/general/${name#*.}" ||
    property="/$(echo ${name#*.} | sed -ne 's:/:\.:g')"

# Extract the operation from the argument[s]
case "${1#-}" in
    "true"|"t"|"on"|1)
	value="true"
	;;
    "false"|"f"|"off"|0)
	value="false"
	;;
    "toggle"|"switch"|"s"|"~")
	old_value="$(${prog} --channel ${channel} --property ${property})"
	case "${old_value}" in
	    "true")	value="false";;
	    "false")	value="true";;
	    *)
		echo "Cannot toggle non-bool value: '${old_value}'" 1>&2
		exit 1
	esac
	;;
    "refresh"|"r")
	value="$(${prog} --channel ${channel} --property ${property})"
	${prog} --channel ${channel} --property ${property} --set 'Default'
	;;
    *)
	value="${1}"
	;;
esac

# Perform the operation
exec ${prog} --channel ${channel} --property ${property} --set ${value}
