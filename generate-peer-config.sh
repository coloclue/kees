#!/bin/bash
set -ev

if [ "${1}" = '-d' -o "${1}" = '--debug' ]; then
    arguments=' debug'
fi

# generate filters and configs
./peering_filters all "${arguments}"

if [ "$(python -c "import yaml,sys;a = yaml.safe_load(sys.stdin); print(a['rpki']['validation']);" < vars/generic.yml)" == "True" ]; then
    if [ ! -d /opt/routefilters/rpki ] ; then
        mkdir /opt/routefilters/rpki
    fi

    ./gentool -4 -y vars/generic.yml -t templates/rpkiwhitelist.j2 -o /opt/routefilters/rpki/rpkiwhitelist-ipv4.conf
    ./gentool -6 -y vars/generic.yml -t templates/rpkiwhitelist.j2 -o /opt/routefilters/rpki/rpkiwhitelist-ipv6.conf
else
    rm -f /opt/routefilters/rpki/rpki-ipv4.conf
    rm -f /opt/routefilters/rpki/rpki-ipv6.conf
fi
