#!/bin/sh
# shellcheck disable=2039
# vi: et sw=4 ts=8 sts=4

# TODO: Only works with GDM at the moment
NAME="$(basename "$0" .sh)"
: "${USER:=$(id -un)}"
: "${USER_VNC_LOG:=${HOME:-/home/$USER}/.vnc/x0vnc.log}"

set -euf
IFS="$(printf '\n\n')"	# $() strips last '\n'

tmp_msg() {
    printf '\r%s' "$1"  # multiline doesn't work
}
msg() {
    printf '\r%s\n' "$@"    # ensure it starts a the begining of the line
}
err() {
    local s=$?; [ $s -gt 0 ] || s=1
    [ $# -lt 1 ] || msg "$@" >&2
    return $s
}
die() { err "$@" || exit; }

command -v x0vncserver >/dev/null ||
    die "x0vncserver: command not found, install tigervnc server"
command -v pgrep >/dev/null || die "pgrep: command not found"

get_pid() {
    local pid=''
    pid="$(pgrep "$@")" || err "Can't find $*" || return
    case "$(echo "$pid" | wc -l)" in
        0)  err "Can't find $*";;
        1)  echo "$pid";;
        *)  err "Multiple found for $*";;
    esac
}

get_session_pid() {
    if [ "${1-}" = -l ]
    then
        get_pid -u gdm gnome-session-b
    else
        get_pid -u "$USER" gnome-session-b
    fi
}

get_vnc_pid() {
    if [ "${1-}" = -l ]
    then
        get_pid -u gdm x0vncserver
    else
        get_pid -u "$USER" x0vncserver
    fi
}

get_x_vars() {
    [ -r "/proc/$1/environ" ] || err "Can't read $1 environ" || return
    tr '\000' '\n' < "/proc/$1/environ" | grep -Ee '^XDG_|^XATH|^DISPLAY'
}

read_passwd() {
    local trap='' stty='' passwd='' status=0
    trap="$(trap | grep -Ee 'EXIT$|INT$')" || :
    [ -n "$trap" ] || trap="trap - EXIT INT"
    if [ -t 0 ]
    then
        stty="$(stty -g)"
        #shellcheck disable=2064
        trap "stty '$stty'" EXIT INT
        printf 'vnc passwd: ' >&2
    fi
    read -r passwd || status=$?
    if [ -t 0 ]
    then
        stty "$stty"
        eval "$trap"
    fi
    [ $status -eq 0 ] || return $status
    echo "$passwd"
}

unset TMP_D
get_tmp_d() {
    [ -d "${TMP_D-}" ] && echo "$TMP_D"
    TMP_D="$(mktemp -t -d "$NAME-$USER.XXXXX")"
    # shellcheck disable=2064
    trap "rm -rf '$TMP_D'" EXIT
    chmod 700 "$TMP_D"
    echo "$TMP_D"
}

gen_passwd() {
    local passwd=''
    tmp_d="$(get_tmp_d)"
    passwd="$tmp_d/passwd"
    printf '%s\n' "$1" "$1" "n" | vncpasswd -f "$passwd" >/dev/null 2>&1 &&
        echo "$passwd"
}

if [ $# -gt 0 ] && [ "$1" = -l ]
then    # running as root - connect to login X display
    if [ "$USER" -ne root ]
    then
        echo "Need to sudo to attach to login screen..."
        exec sudo "$0" "$@"
    fi
    shift   # the -l

    if vnc_pid="$(get_vnc_pid -l)"
    then
        echo "gdm x0vncserver already running (pid: $vnc_pid)"
        exit
    fi

    [ $# -gt 1 ] || [ -f "$1" ] ||
        die "Usage: $0 [-l] <passwd-file> [x0vncserver-args...]"

    passwd="$1"; shift
    login_pid="$(get_session_pid -l)" || die
    x_vars="$(get_x_vars "$login_pid")"

    tmp_d="$(get_tmp_d)"
    cp "$passwd" "$tmp_d/passwd"
    chown gdm: -R "$tmp_d"

    # shellcheck disable=2086
    exec sudo -u gdm env $x_vars x0vncserver -PasswordFile="$tmp_d/passwd"
fi

# Running as user, main script
if [ $# -lt 1 ]
then
    passwd="$HOME/.vnc/passwd"
    # If it doesn't exist, prompt as vncserver would
    [ -f "$passwd" ] || {
        msg "You will require a VNC password"
        vncpasswd
    }
else
    if [ "$1" = - ]
    then
        passwd="$(gen_passwd "$(read_passwd)")"
    elif [ -f "$1" ]
    then
        passwd="$1"
    else
        passwd="$(gen_passwd "$1")"
    fi
    shift
fi
[ -f "$passwd" ] ||
    die "Usage: $0 [passwd-file|passwd|-]"

user_session="$USER graphical session"
login_session="Login graphical session"
session_pid=''
login_pid=''
vnc_pid=''

while ! session_pid="$(get_session_pid)"
do
    if [ -z "$login_pid" ]
    then
        echo "Need to start $login_session, aquiring sudo..."
        sudo "$0" -l "$passwd" &
        login_pid=$!
    elif ! sudo kill -0 "$login_pid" >/dev/null 2>&1
    then
        die "$login_session process died"
    elif [ -z "$vnc_pid" ] && vnc_pid="$(get_vnc_pid -l)"
    then
        msg "$login_session VNC started (pid: $vnc_pid)" \
            "Connect and login (default port)"
        login_pid="$vnc_pid"    # store as login for kill
    elif [ -n "$vnc_pid" ]
    then
        i=$(( ${i-0} + 1 ))
        tmp_msg '\r... waiting for connect and login: %ds' $i
    fi
    sleep 1
done

msg "$user_session started"

if [ -n "$login_pid" ]
then
    msg "Killing $login_session VNC"
    sudo kill "$login_pid"
    for i in $(seq 10)
    do
        sleep 1
        sudo kill -0 "$login_pid" >/dev/null 2>&1 || break
        tmp_msg "... waiting for $login_session VNC to die: ${i}s"
        false
    done || die "$login_session hasn't died"
fi

[ -n "$x_vars" ] || x_vars="$(get_x_vars "$session_pid")"

if ! vnc_pid="$(get_vnc_pid)"
then
    [ -e "$USER_VNC_LOG" ] || mkdir -p "$(dirname "$USER_VNC_LOG")" || die
    msg "Starting $user_session VNC in background..."
    # the subshell with setsid is to fully disconnect the process
    # shellcheck disable=2086
    ( setsid env $x_vars x0vncserver -PasswordFile="$passwd" > "$USER_VNC_LOG" 2>&1 & )
    for i in $(seq 10)
    do
        sleep 1
        vnc_pid="$(get_vnc_pid)" && break
        tmp_msg "... waiting for $user_session VNC to start: ${i}s"
    done || die "$user_session VNC hasn't started"
fi

msg "$user_session VNC started (pid: $vnc_pid)" \
    "Ready for (re)connect (default port)"

