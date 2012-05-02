#!/bin/sh
# SCRIPTS_DIR/lib/expr.sh
# Variables for common glob/regular expression tests


# booleans
_true='[Tt][Rr][Uu][Ee]'
_false='[Ff][Aa][Ll][Ss][Ee]'
rgx_bool="${_true}\\|${_false}"

# yes / no
#rgx_yes='[Yy]\([Ee][Ss]\)\?'	# This is better...
rgx_yes='[Yy]\|[Yy][Ee][Ss]'	# ... but this doesn't mess up group numbering
rgx_no='[Nn][Oo]\?'
rgx_yn="${rgx_yes}\\|${rgx_no}"

# unix users
rgx_id='[0-9]\+'
rgx_user='[a-z_]\{1,32\}[$]\?'	# trailing '$' should be 32nd not 33rd...

# devices
rgx_pty='pts\/[0-9]\+'
rgx_tty='tty[0-9]\+'
rgx_term="${rgx_pty}\\|${rgx_tty}"
rgx_xdply='\:[0-9]\+.[0-9]\+'

