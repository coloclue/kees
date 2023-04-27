#!/bin/bash
set -ev

. functions.sh

if [ "${1}" == '-d' -o "${1}" == '--debug' ]; then
    arguments='debug'
fi

# Get output/staging dirs from Kees configuration
BUILDDIR=${BUILDDIR:-`getconfig 'builddir' '/opt/routefilters'`}
echo Building in \'${BUILDDIR}\'

# generate filters and configs
./peering_filters all "${arguments}"

if [ "$(getconfig "rpki']['validation" False)" == "True" ]; then
    if [ ! -d ${BUILDDIR}/rpki ] ; then
        mkdir ${BUILDDIR}/rpki
    fi

    ./gentool -4 -y vars/generic.yml -t templates/rpkiwhitelist.j2 -o ${BUILDDIR}/rpki/rpkiwhitelist-ipv4.conf
    ./gentool -6 -y vars/generic.yml -t templates/rpkiwhitelist.j2 -o ${BUILDDIR}/rpki/rpkiwhitelist-ipv6.conf
else
    rm -f ${BUILDDIR}/rpki/rpki-ipv4.conf
    rm -f ${BUILDDIR}/rpki/rpki-ipv6.conf
fi
