#!/bin/sh
# SCRIPTS_DIR/lib/status.sh
# Helpers for storing/manipulating the return/exit status

${source_status-true} &&
    source_status=false ||
    return 0

_st_total=0
_st_last=0

# Echos and returns the combined status
st() {
    echo $_st_total
    return $_st_total
}

# Echos and returns the last recorded status
last_st() {
    echo $_st_last
    return $_st_last
}

# Exits with the combined status
exit_st() {
    exit $_st_total
}

# Increments the status by the given amount (or 1), returning the new total.
inc_st() {
    _st_last=$?
    _st_total=$(( $_st_total + ${1:-1} ))
    return $_st_total
}

# Combines the previous commands exit status with the current combined status,
# returning the new status.
comb_st() {
    inc_st $?
}

