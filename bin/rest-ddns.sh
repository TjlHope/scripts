#!/bin/sh
# vi: sw=4 sts=4 ts=8 et
set -eu
[ -z "${SH_OPTS-}" ] || set -"${SH_OPTS#-}"

SCRIPT="$0"
NAME="$(basename "$0" .sh)"
: "${TMPDIR:=/tmp}"

[ -z "${NC-}" ] || eval "nc() { $NC \"\$@\"; }"
NL="$(printf '\n#')"; NL="${NL%#}"
IFS="$NL"

# shellcheck disable=2015
msg() { [ $# -gt 0 ] && printf '%s\n' "$@" || :; }
err() {
    # shellcheck disable=2039
    local s=$?; [ $s -gt 0 ] || s=1
    msg "$@" >&2
    return $s
}
die() { err "$@" || exit; }

rest_ddns__usg() {
    # shellcheck disable=2039
    local s=$?; [ $# -gt 0 ] && [ $s -gt 0 ] || s=1
    [ $s -eq 0 ] || { exec >&2; msg "$@" ""; }
    cat <<_EOF
Usage: $0 [-ls|-LS] [-pPORT] [-dDIR] <ZONE> [-] [HOST:[IP] ...]

ZONE                the DNS Zone to modify
HOST:[IP]           a hostname and IP pair to enter into ZONE
                    (a missing IP translates to a DELETE)

-, -r, --request    read stdin for a REST DDNS request
-R, --no-request    don't read stding for a REST DDNS request (default)
-l, --listen        listen for REST requests (default unless -)
-L, --no-listen     don't listen for REST requests
-s, --signal        signal (HUP) dnsmasq on update (default)
-S, --no-signal     don't signal (HUP) dnsmasq on update
-p, --port=PORT     the port to listen on (default: 8053)
-d, --dir=DIR       the (dnsmasq style) hostdir to modify
                    (default: $TMPDIR/$NAME/<ZONE>

When run in listen mode, it uses nc to spawn itself in request mode for each
request. Each request is expected to already be validated, and provide the
hostname in the request path, and the IP in the X-Real-IP header.
_EOF
    exit $s
}

rest_ddns__parse() {
    unset ZONE PORT DIR; REQUEST=-R LISTEN="" SIGNAL=-s ENTRIES=""
    # shellcheck disable=2039
    local a="" o="" r=""
    while [ $# -gt 0 ]
    do  a="$1"; shift
        case "$a" in
            -[rRlLsSh]?*)   r="${a#-?}" o="${a%$r}"; set -- "$o" "-$r" "$@";;
            -[pd]?*)        r="${a#-?}" o="${a%$r}"; set -- "$o" "-$r" "$@";;
            --*=*)          r="${a#--*=}" o="${a%%=*}"; set -- "$o" "$r" "$@";;
            -|-r|--request) REQUEST=-r;;
            -R|--no-request) REQUEST=-R;;
            -l|--listen)    LISTEN=-l;;
            -L|--no-listen) LISTEN=-L;;
            -s|--signal)    SIGNAL=-s;;
            -S|--no-signal) SIGNAL=-S;;
            -h|--help)  rest_ddns__usg;;
            -p|--port)  PORT="${2-}";;
            -d|--dir)   DIR="${2-}";;
            -*)     rest_ddns__usg "Unknown argument: $a";;
            *:*)    ENTRIES="$ENTRIES$NL$a";;
            *)      if [ "${ZONE+set}" = set ] 
                    then
                        rest_ddns__usg "Multiple zones provided:" "$ZONE" "$a"
                    else
                        ZONE="$a"
                    fi;;
        esac
    done
    [ -n "${ZONE-}" ] || rest_ddns__usg "No zone provided"
    ZONE="${ZONE#.}"; ZONE="${ZONE%.}"
    [ -n "${LISTEN}" ] || [ "$REQUEST" = -R ] && LISTEN=-l || LISTEN=-L
    [ "${PORT=8053}" -gt 0 ] || rest_ddns__usg "Invalid port: $PORT"
    [ -n "${DIR-}" ] || DIR="$TMPDIR/$NAME/$ZONE"
    {
        { [ -d "$DIR" ] || mkdir -p "$DIR"; } &&
        echo "0.0.0.0 _test" > "$DIR/_test" &&
        rm "$DIR/_test"
    } || rest_ddns__usg "Cannot use directory: $DIR"
}

rest_ddns__signal() {
    [ $# -eq 0 ] || err "Usage: rest_ddns__signal" || return
    # TODO: generic signal mechanism?
    [ "$SIGNAL" = -s ] || return 0
    # shellcheck disable=2046
    kill -HUP $(pidof dnsmasq) || err "Failed to signal($?) dnsmasq"
}

rest_ddns__delete() {
    [ $# -eq 1 ] || err "Usage: rest_ddns__delete <HOST>..." || return
    # shellcheck disable=2039
    local s=0
    while [ $# -gt 0 ]
    do
        rm "$DIR/$1.conf" ||
            err "Failed to update($?): $1" || s=$((s+1))
        shift
    done
    rest_ddns__signal || s=$((s+1))
    return $s
}

rest_ddns__update() {
    [ $# -eq 1 ] || err "Usage: rest_ddns__update <HOST:[IP]>..." || return
    # shellcheck disable=2039
    local s=0 host="" ip=""
    while [ $# -gt 0 ]
    do
        host="${1%%:*}" ip="${1#*:}"
        if [ -n "$ip" ]
        then
            printf '%s\t%s.%s %s\n' "$ip" "$host" "$ZONE" "$host" \
                > "$DIR/$host.conf" ||
                err "Failed to update($?): $1" || s=$((s+1))
        else
            rest_ddns__delete "$host"
        fi
        shift
    done
    rest_ddns__signal || s=$((s+1))
    return $s
}

rest_ddns__listen() {
    [ $# -eq 0 ] || err "Usage: PORT=? ZONE=? rest_ddns__listen" || return
    nc -l -p "$PORT" -k -e "$SCRIPT" "$SIGNAL" "$ZONE" -
}

rest_ddns__request() {
    # shellcheck disable=2039
    local IFS="" method="" path="" proto="" header="" value="" \
        host="" ip="" status="200 OK" body="" s=0
    IFS="$(printf ' \t\r\n#')"; IFS="${IFS%#}"
    read -r method path proto
    host="${path#/}"; host="${host%/}"
    while read -r header value
    do
        case "$header" in
            "") break;;
            [Xx]-[Rr]eal-[Ii][Pp]:)  ip="$value";;
            *)  :;;
        esac
    done
    if case "$host" in ""|*/*) :;; *) false; esac
    then
        s=4 status="400 Bad Request"
        body="Invalid host: $host"
    elif case "$proto" in 'HTTP/1.'[01]) false;; *) :; esac
    then
        s=4 status="400 Bad Request"
        body="Unexpected protocol: $proto"
    else
        case "$method" in
            POST|PUT)
                if [ -z "$ip" ]
                then
                    s=4 status="400 Bad Request"
                    body="No IP provided with X-Real-IP header"
                else
                    body="$(rest_ddns__update "$host:$ip" 2>&1)" ||
                        s=5 status="500 Internal Server Error"
                fi;;
            DELETE)
                # TODO: also show 404 not found?
                body="$(rest_ddns__delete "$host" 2>&2)" ||
                    s=5 status="500 Internal Server Error";;
            *)
                s=4 status="406 Method Not Allowed"
                body="Method Not Allowed: $method";;
        esac
    fi
    # shellcheck disable=2086
    body="$(IFS="$NL" && printf '%s\r\n' $body)"
    printf '%s\r\n' \
        "HTTP/1.1 $status" \
        "Date: $(date "+%a, %d %b %Y %T %Z")" \
        "Connection: close" \
        "Content-Type: text/plain" \
        "Content-Length: $((${#body}+2))" \
        "" \
        "$body"
    return $s
}

rest_ddns__main() {
    # shellcheck disable=2039
    local ZONE="" REQUEST="" LISTEN="" SIGNAL="" PORT=0 DIR="" ENTRIES=""
    rest_ddns__parse "$@"
    if [ -n "$ENTRIES" ]
    then
        rest_ddns__update $ENTRIES
    fi
    if [ "$LISTEN" = -l ]
    then 
        # shellcheck disable=2039
        local pid=""
        rest_ddns__listen &
        pid=$!
    fi
    if [ "$REQUEST" = -r ]
    then
        rest_ddns__request
    fi
    if [ "$LISTEN" = -l ]
    then
        wait "$pid"
    fi
}

case "$NAME" in
    rest[-_]ddns)   rest_ddns__main "$@";;
esac
