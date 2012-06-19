#!/bin/sh
# SCRIPTS_DIR/lib/percent_blocks.sh
# Functions to display percentages using unicode block characters.

${source_percent_blocks-true} &&
    source_percent_blocks=false ||
    return 0

_bf00=" "	# u0020 space
_bu12="▀"	# u2580 upper half block
_bd18="▁"	# u2581 lower one eighth block
_bd14="▂"	# u2582 lower one quarter block
_bd38="▃"	# u2583 lower three eighths block
_bd12="▄"	# u2584 lower half block
_bd58="▅"	# u2585 lower five eighths block
_bd34="▆"	# u2586 lower three quarters block
_bd78="▇"	# u2587 lower seven eighths block
_bf11="█"	# u2588 full block
_bl78="▉"	# u2589 left seven eighths block
_bl34="▊"	# u258A left three quarters block
_bl58="▋"	# u258B left five eighths block
_bl12="▌"	# u258C left half block
_bl38="▍"	# u258D left three eighths block
_bl14="▎"	# u258E left one quarter block
_bl18="▏"	# u258F left one eighth block
_br12="▐"	# u2590 right half block

pc_vblock () {	# FIXME: Rounding Errors
    # Output single Unicode block characters to (vertically) represent the 
    # percentages passed as arguments.
    # Return values: 0 = OK; 1 = Out of Bounds; 2 = Invalid.
    local vblock
    while [ -n "${1}" ]
    do
	if [ -n "${1#[0-9]}" -a \
	    -n "${1#[0-9][0-9]}" -a \
	    -n "${1#[0-9][0-9][0-9]}" ]
	then
	    return 2
	elif [ ${1} -lt 0 ]; then	# Out of Bounds
	    return 1
	elif [ ${1} -lt 6 ]; then	# < 6.25
	    vblock="${vblock}${_bf00}"
	elif [ ${1} -le 18 ]; then	# < 18.75
	    vblock="${vblock}${_bd18}"
	elif [ ${1} -lt 31 ]; then	# < 31.25
	    vblock="${vblock}${_bd14}"
	elif [ ${1} -le 43 ]; then	# < 43.75
	    vblock="${vblock}${_bd38}"
	elif [ ${1} -lt 56 ]; then	# < 56.25
	    vblock="${vblock}${_bd12}"
	elif [ ${1} -le 68 ]; then	# < 68.75
	    vblock="${vblock}${_bd58}"
	elif [ ${1} -lt 81 ]; then	# < 81.25
	    vblock="${vblock}${_bd34}"
	elif [ ${1} -le 93 ]; then	# < 93.75
	    vblock="${vblock}${_bd78}"
	elif [ ${1} -le 100 ]; then	# <= 100
	    vblock="${vblock}${_bf11}"
	else			# Out of Bounds
	    return 1
	fi
	shift
    done
    echo "${vblock}"
}

pc_hblock () {	# FIXME: Rounding Errors
    # Output ${2:-4} Unicode block characters to (horizontally) represent a 
    # percentage. Return values: 0 = OK; 1 = Out of Bounds; 2 = Invalid.
    local p w n i hblock
    if [ -z "${1}" ] || [ -n "${1#[0-9]}" -a \
			    -n "${1#[0-9][0-9]}" -a \
			    -n "${1#[0-9][0-9][0-9]}" ]
    then
	return 2
    else
	p="${1}"
    fi
    if [ -n "${2#[0-9]}" -a \
	-n "${2#[0-9][0-9]}" -a \
	-n "${2#[0-9][0-9][0-9]}" ]
    then
	return 2
    else
	w="${2:-4}"
    fi
    n=$(( 100 / ${w} ))
    while [ ${i:=${n}} -lt ${p} ]
    do
	hblock="${hblock}${_bf11}"
	i=$(( ${i} + ${n} ))
    done
    p=$(( (${p} - (${i} - ${n})) * ${w} ))
    if [ ${p} -lt 0 ]; then	# Out of Bounds
	return 1
    elif [ ${p} -lt 6 ]; then	# < 6.25
	hblock="${hblock}${_bf00}"
    elif [ ${p} -le 18 ]; then	# < 18.75
	hblock="${hblock}${_bl18}"
    elif [ ${p} -lt 31 ]; then	# < 31.25
	hblock="${hblock}${_bl14}"
    elif [ ${p} -le 43 ]; then	# < 43.75
	hblock="${hblock}${_bl38}"
    elif [ ${p} -lt 56 ]; then	# < 56.25
	hblock="${hblock}${_bl12}"
    elif [ ${p} -le 68 ]; then	# < 68.75
	hblock="${hblock}${_bl58}"
    elif [ ${p} -lt 81 ]; then	# < 81.25
	hblock="${hblock}${_bl34}"
    elif [ ${p} -le 93 ]; then	# < 93.75
	hblock="${hblock}${_bl78}"
    elif [ ${1} -le 100 ]; then	# <= 100
	hblock="${hblock}${_bf11}"
    else			# Out of Bounds
	return 1
    fi
    i=$(( ${i} + ${n} ))
    while [ ${i} -lt $(( 100 + ${n} )) ]
    do
	hblock="${hblock}${_bf00}"
	i=$(( ${i} + ${n} ))
    done
    echo "${hblock}"
}

