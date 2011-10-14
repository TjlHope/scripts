#!/bin/sh
# Small script to manipulate the display as I want 

prog="/usr/bin/xrandr"
posistion="below"

case "$(/bin/basename $0)" in
    "display.dual")
	display='LVDS1'
	secondary="$(${prog} --query | \
	    sed -ne "/^\(Screen\|${display}\|\s\)/"'!s/^\(\w\+\).*/\1/p')"
	# TODO: secondary will currently select *all* other screens :-s 
	;;

    "display.orientate")
	case "${1}" in
	    "n"|"normal"|"u"|"up"|"0")
		rotate="normal";;
	    ""|"l"|"left"|"1"|"-90")	# default
		rotate="left";;
	    "i"|"inverted"|"d"|"down"|"2"|"180")
		rotate="inverted";;
	    "r"|"right"|"3"|"90")
		rotate="right";;
	    *)
		echo "Usage: $0 [{normal,up}|left|{inverted,down}|right]" 1>&2
		echo "	Also accepts position or angle for action." 1>&2
	esac
	;;

    "display.rotate")
	#TODO: allow reletive rotation
	case "${1}" in
	    ""|"l"|"left"|"-90")	# default
		rotate="left";;
	    "r"|"right"|"90")
		rotate="right";;
	    "i"|"invert"|"180")
		rotate="inverted";;
	    *)
		echo "Usage: $0 [left|right|inver]" 1>&2
		echo "	Also accepts angle for action." 1>&2
	esac
	;;

    *)
	echo "${0} is not a valid command" >&2
	exit 1
	;;

esac

${prog} ${display+--output ${display} --auto} \
    ${rotate+${display---orientation}${display+--rotate} ${rotate}} \
    ${secondary+--output ${secondary} --auto --${posistion} ${display}}

# Do we need to restart the xfce4-panel?
#sleep 5
#/usr/bin/pgrep xfce4-panel >/dev/null &&
    #/usr/bin/xfce4-panel --restart
