#!/bin/bash
# Support functions for Kees scripts

function getconfig () {
    varname=$1
    default=$2

    set +ev # Python errors are fine, since we have a default value
    # TODO  This is really fragile when dealing with non-scalar variables
    value=$(python3 -c "import yaml,sys;a = yaml.safe_load(sys.stdin); print(a['$varname']);" < vars/generic.yml 2>/dev/null)
    rc=$?
    set -ev
    if [ ${rc} -eq 0 ]; then
        echo ${value}
        return
    fi
    echo ${default}
    return
}
