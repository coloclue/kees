#!/bin/bash
set -ev

# generate filters and configs
./peering_filters all

if [ "$(python3 -c "import yaml,sys;a = yaml.safe_load(sys.stdin); print(a['rpki']['validation']);" < vars/generic.yml)" == "True" ]; then
    if [ ! -d /opt/routefilters/rpki ]; then
        mkdir /opt/routefilters/rpki
    fi

    rpki_json_urls="$(python3 -c "import yaml,sys; generic_yaml = yaml.safe_load(sys.stdin); print(generic_yaml['rpki_json_urls']);" < vars/generic.yml 2>/dev/null)"

    if [ -z "$rpki_json_urls" ]; then
        rtrsub_options=()
    elif ./merge_rpki_json_urls.py < vars/generic.yml 2>/dev/null; then
        rtrsub_options=(-c /tmp/kees-roas.json)
    else
        echo "ERROR: could not set rtrsub_options!"
        exit 1
    fi

    rtrsub --afi ipv4 "${rtrsub_options[@]}" < ./templates/bird-rpki.j2 > /opt/routefilters/rpki/rpki-ipv4.conf
    rtrsub --afi ipv6 "${rtrsub_options[@]}" < ./templates/bird-rpki.j2 > /opt/routefilters/rpki/rpki-ipv6.conf

    if [ ${#rtrsub_options[@]} -ne 0 ]; then
        rm -f /tmp/kees-roas.json
    fi

    ./gentool -4 -y vars/generic.yml -t templates/rpkiwhitelist.j2 -o /opt/routefilters/rpki/rpkiwhitelist-ipv4.conf
    ./gentool -6 -y vars/generic.yml -t templates/rpkiwhitelist.j2 -o /opt/routefilters/rpki/rpkiwhitelist-ipv6.conf
else
    rm -f /opt/routefilters/rpki/rpki-ipv4.conf
    rm -f /opt/routefilters/rpki/rpki-ipv6.conf
fi
