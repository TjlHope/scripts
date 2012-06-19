#!/bin/sh
# SCRIPTS_DIR/lib/status.sh
# Helpers for storing/manipulating the return/exit status

${source_status-true} &&
    source_status=false ||
    return 0

st_total=0

inc_st () {
    st_total=$(( ${st_total} + ${1:-1} ))
    return ${st_total}
}

st_last=0

comb_st () {
    st_last=${?}
    st_total=$(( ${st_total} + ${st_last} ))
    return ${st_total}
}

