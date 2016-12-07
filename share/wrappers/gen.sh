#!/bin/sh
# SCRIPTS_DIR/share/wrappers/find.sh

[ -h "$0" ] && this="$(readlink -f "$0")" || this="$0"
name="${0##*/}"
lib_d="${this%/*/*/*}/lib"
src_d="${this%/*/*}/src"
gen_d="$src_d/gen"

. "$lib_d/output.sh"

# Parse wrapper arguments
force=false
while [ $# -gt 0 ]
do
    case "$1" in
        -[vxfh\?][vxfh\?]*)
            rest="${1#-?}"; first="${1%$rest}"; shift
            set -- "$first" "-$rest" "$@"
            continue;;
        -v) verbose=true;;
        -x) set -x;;
        -f) force=true;;
        -h|-\?|--help)
            cat <<- _EOF
		Usage: $0 [-v] [-x] [-f] [-h] <$name arguments>
		  A wrapper script to generate and run $name.
		
		Arguments:
		  -v    verbose wrapper operation
		  -x    turn on shell debug (set -x)
		  -f    verbose wrapper operation
		  -h, -?, --help
		        display this help message and $name's help message
		
		_EOF
            break;;
    esac
    shift
done

info "Looking for source file: $src_d/$name.*"
unset src_f
for f in "$src_d/$name".*
do
    if [ -f "$f" ] && [ -z "$src_f" ]
    then src_f="$f"
        info "Found source file: $src_f"
        $verbose || break
    else
        warn "Ignoring: $f"
    fi
done
[ -f "$src_f" ] || die "Cannot find source file: $src_f"

gen_f="$gen_d/$name"    # Generate if necessary
if $force || [ ! -x "$gen_f" ] || [ "$src_f" -nt "$gen_f" ]
then
    info "Generating: $gen_f"
    info "      from: $src_f"
    [ -d "$gen_d" ] || mkdir "$gen_d"   # no -p as $src_d must exist here
    args="$(sed -ne '1,5{s/^.*gen\.sh\s*:\s*\([^:]*\):\?\s*$/\1/p}' "$src_f")"
    case "$src_f" in            # let's try and be polite about size
        *.c)            gcc -Os -s "$src_f" -o "$gen_f" $args;;
        *.c[px][px])    g++ -Os -s "$src_f" -o "$gen_f" $args;;
        *)              die "Don't know how to generate from: $src_f";;
    esac || die "Failed to generate from: $src_f"
fi

info "Executing: $gen_f"
exec "$gen_f" "$@"
