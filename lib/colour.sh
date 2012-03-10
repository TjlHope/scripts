#!/bin/sh
# SCRIPTS_DIR/lib/colour.sh
# Variables for ANSI colour escape sequences

# Control codes
_eb='['	# begin
_es=';'		# seperator
_ee='m'		# end

# Attribute codes
_an='0'		# reset (none)
_ab='1'		# bold/bright
_ad='2'		# dim
_au='4'		# underline
_aa='5'		# blink (annoy)
_ar='7'		# reverse
_ah='8'		# hidden
_ai='8'		# invisible

# Colour codes
_cfg='3'	# forground colour
_cbg='4'	# background colour
_ck='0'		# black
_cr='1'		# red
_cg='2'		# green
_cy='3'		# yellow
_cb='4'		# blue
_cm='5'		# magenta
_cc='6'		# cyan
_cw='7'		# white
_cd='9'		# default
_cn='9'		# default

# Helper Functions

_colour_code () {	# colour
    local colour code
    [ "${1}" = "none" ] &&
	return
    [ "${1}" = "black" ] &&	# 'black' conflicts with 'blue'
	colour="k" ||		# ... so 'k' (key) is used
	colour="${1%${1#?}}"	# strip (arg without first char) from the end.
    eval 'code="${_c'"${colour}"'}"'	# evaluate to colour code
    [ -z "${code}" ] &&		# if no code
	return 1		# ... return false
    echo "${code}"		# output code
}

_attr_code () {		# attribute
    local attr code
    [ "${1}" = "reset" ] &&	# 'reset' conflicts with 'reverse'
	attr="n" ||		# ... so 'n' (none) is used
    [ "${1}" = "blink" ] &&	# 'blink' conflicts with 'bold'/'bright'
	attr="a" ||		# ... so 'a' (annoy) is used
	attr="${1%${1#?}}"	# strip (arg without first char) from the end.
    eval 'code="${_a'"${attr}"'}"'	# evaluate to colour code
    [ -z "${code}" ] &&		# if no code
	return 1		# ... return false
    echo "${code}"		# output code
}

_refresh_fmt () {	# [prefix]
    local codes code
    eval "${1}fmt='${_eb}'"	# reset $fmt string
    eval 'codes="'"\${${1}_fgclr} \${${1}_bgclr} \${${1}_attr}"'"'
    for code in ${codes}
    do
	eval "${1}fmt="'"${'"${1}fmt}${code}${_es}"'"'	# add code to string
    done
    eval "${1}fmt="'"${'"${1}fmt%${_es}}${_ee}"'"'	# terminate string
}

# Setting functions

set_fg_colour () {	# colour [prefix]
    local code="$(_colour_code "${1}")" ||
	return			# get colour code or return
    eval "${2}_fgclr='${_cfg}${code}'"	# set foreground colour code
    _refresh_fmt ${2}		# refresh format string
}

set_bg_colour () {	# colour [prefix]
    local code="$(_colour_code "${1}")" ||
	return			# get colour code or return
    eval "${2}_bgclr='${_cbg}${code}'"	# set background colour code
    _refresh_fmt ${2}		# refresh format string
}

set_attr () {		# attribute [prefix]
    local code="$(_attr_code "${1}")" ||
	return			# get attribute code or return
    eval "${2}_attr='${code}'"	# set attribute code
    _refresh_fmt "${2}"		# refresh format string
}

