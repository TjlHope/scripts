#!/bin/sh
# vi: sw=4 sts=4 ts=8 et
[ -z "${SH_OPTS-}" ] || set -"${SH_OPTS#-}"
set -euf
NL="$(printf '\n#')"; NL="${NL%#}"
_IFS="$IFS" IFS="$NL"

run_in_X__usage() {
    # shellcheck disable=2039
    local s=$?
    cat <<_EOF
Usage: $0 [-sSESSION PID|CMD] [-uUSER] [-tTTY] [--] [CMD [ARGS...]]

Runs the given command in the discovered X session.

Argusments:
  -sSESSION, --session=SESSION
                a PID, name (GNOME/XFCE), or command (e.g. gnome-session-b)
                used to discover the X session (default: \$RUN_IN_X_SESSION, or
                \$XDG_CURRENT_DESKTOP)
  -uUSER, --user=USER
                the user used to search for SESSION (default to current
                (effecitve) user.
  -tTTY, --tty=TTY
                a comma separated list of TTYs to search for SESSION
                (default tty[1-7] - for GNOME).
  --            stop processing $(basename "$0" .sh) arguments.
  CMD [ARGS...] the command and arguments to run, if not specified, the
                necessary argument variables will be echo'd to stdout.

_EOF
    exit $s
}

msg() {
    printf '%s\n' "$@"
}
err() {
    # shellcheck disable=2039
    local s=$?; [ $s -gt 0 ] || s=1
    [ $# -lt 1 ] || msg "$@" >&2
    return $s
}
die() { err "$@" || exit; }

secho() {
    # shellcheck disable=2039
    local IFS="$_IFS"
    # shellcheck disable=2048,2086
    echo $*
}


get_1() {
    # shellcheck disable=2039
    local lines='' IFS="$NL"
    lines="$(cat)"
    [ -n "$lines" ] || return 1
    case "$(echo "$lines" | wc -l)" in
        0)  return 1;;
        1)  echo "$lines";;
        *)  echo "${lines%%$NL}"
            return 2;;
    esac
}

get_pid() {
    pgrep "$@" | get_1 "$@"
}

get_x_vars() {
    [ $# -eq 1 ] || err "Usage: get_x_vars <pid>" || return
    [ -r "/proc/$1/environ" ] || err "Can't read $1 environ" || return
    tr '\000' '\n' < "/proc/$1/environ" | grep -Ee '^XAUTHORITY|^DISPLAY'
}

run_in_X() {
    # shellcheck disable=2039
    local a="" r="" \
        session="${RUN_IN_X_SESSION:-${XDG_CURRENT_DESKTOP:-}}" \
        user="${USER-${EUID-$(id -u)}}" \
        _tty="tty1,tty2,tty3,tty4,tty5,tty6,tty7" tty="-" \
        prog="" pid="" x_vars="" exec=""
    while [ $# -gt 0 ]
    do
	case "$1" in
	    -h|--help)      run_in_X__usage;;
            -[!-]?*)        r="${1#-?}"; a="${1%$r}"; shift
                            set -- "$a" "$r" "$@";;
            --*=*)          a="${1%%=*}" r="${1#*=}"; shift
                            set -- "$a" "$r" "$@";;
            -s|--session)   session="$2"; shift 2;;
	    -u|--user)      user="$2"; shift 2;;
            -t|--tty)       tty="$2"; shift 2;;
	    --)             shift; break;;
            *)              break;;
	esac
    done
    case "$session" in
        '') err "No session provided" || return;;
        [0-9]|[0-9]*[0-9])
            pid="$session";;
        *)
            case "$session" in
                [Xx][Ff][Cc][Ee]|[Xx][Ff][Cc][Ee]4)
                    prog=xfce4-session;;
                [Gg][Nn][Oo][Mm][Ee])
                    # gnome-session-binary seems to need to be
                    # limited to a tty by default
                    [ "$tty" != - ] || tty="$_tty"
                    prog=gnome-session-b;;
                # TODO: KDE, LXDE, OpenBox, etc...
                *)  prog="$session";;
            esac
            [ "$tty" != - ] || tty=""
            pid="$(get_pid ${user:+-u"$user"} ${tty:+-t"$tty"} "$prog")" ||
                case "$?" in
                    1)  err "Session ($prog) not found";;
                    2)  err "Multiple sessions ($prog) found";;
                    *)  err "Failed to get PID for session ($prog)";;
                esac || return
            ;;
    esac
    [ "$pid" -gt 0 ] 2>/dev/null || err "Invalid sessionPID: $pid" || return
    x_vars="$(get_x_vars "$pid")" || return
    case "${EXEC-}" in
        [Ee][Xx][Ee][Cc]|[Yy]|[Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|1) exec="exec";;
        *) exec="";;
    esac
    if [ $# -gt 0 ]
    then    # run the cmd
        # shellcheck disable=2086
        $exec env $x_vars "$@"
    else    # just echo the vars
        $exec echo "$x_vars"
    fi
}

if [ "$(basename "$(readlink -f "$0")" .sh)" = run_in_X ]
then
  EXEC=true run_in_X "$@"
fi
