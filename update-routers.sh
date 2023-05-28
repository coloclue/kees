#!/bin/bash
set -ev

# Ensure /usr/sbin/bird{,6} are in the path.
PATH=$PATH:/usr/sbin

if [ "${1}" == '-d' -o "${1}" == '--debug' ]; then
    arguments='debug'
fi

#routers='dcg-1.router.nl.coloclue.net dcg-2.router.nl.coloclue.net eunetworks-2.router.nl.coloclue.net eunetworks-3.router.nl.coloclue.net'
routers='dcg-1.router.nl.coloclue.net  dcg-2.router.nl.coloclue.net eunetworks-2.router.nl.coloclue.net eunetworks-3.router.nl.coloclue.net'

. functions.sh

# Get output/staging dirs from Kees configuration
BUILDDIR=${BUILDDIR:-`getconfig 'builddir' '/opt/routefilters'`}
echo Building in \'${BUILDDIR}\'
STAGEDIR=${STAGEDIR:-`getconfig 'stagedir' '/opt/router-staging'`}
echo Staging files in \'${STAGEDIR}\'

# generate peer configs
./peering_filters configs "${arguments}"

for router in ${routers}; do
    rm -rf ${STAGEDIR}/${router}
    mkdir -p ${STAGEDIR}/${router}

    ./gentool -y vars/generic.yml -t templates/envvars.j2 -o ${STAGEDIR}/${router}/envvars
    ./gentool -y vars/generic.yml vars/${router}.yml -t templates/ebgp_state.j2 -o ${STAGEDIR}/${router}/ebgp_state.conf

    ./gentool -4 -y vars/generic.yml vars/${router}.yml -t templates/header.j2 -o ${STAGEDIR}/${router}/header-ipv4.conf
    ./gentool -6 -y vars/generic.yml vars/${router}.yml -t templates/header.j2 -o ${STAGEDIR}/${router}/header-ipv6.conf
    ./gentool -4 -y vars/generic.yml vars/${router}.yml -t templates/bfd.j2 -o ${STAGEDIR}/${router}/bfd-ipv4.conf
    ./gentool -6 -y vars/generic.yml vars/${router}.yml -t templates/bfd.j2 -o ${STAGEDIR}/${router}/bfd-ipv6.conf
    ./gentool -4 -y vars/generic.yml vars/${router}.yml -t templates/ospf.j2 -o ${STAGEDIR}/${router}/ospf-ipv4.conf
    ./gentool -6 -y vars/generic.yml vars/${router}.yml -t templates/ospf.j2 -o ${STAGEDIR}/${router}/ospf-ipv6.conf

    ./gentool -4 -y vars/generic.yml vars/${router}.yml -t templates/ibgp.j2 -o ${STAGEDIR}/${router}/ibgp-ipv4.conf
    ./gentool -6 -y vars/generic.yml vars/${router}.yml -t templates/ibgp.j2 -o ${STAGEDIR}/${router}/ibgp-ipv6.conf

    ./gentool -4 -y vars/generic.yml vars/${router}.yml -t templates/interfaces.j2 -o ${STAGEDIR}/${router}/interfaces-ipv4.conf
    ./gentool -6 -y vars/generic.yml vars/${router}.yml -t templates/interfaces.j2 -o ${STAGEDIR}/${router}/interfaces-ipv6.conf

    ./gentool -y vars/generic.yml vars/${router}.yml -t templates/generic_filters.j2 -o ${STAGEDIR}/${router}/generic_filters.conf

    ./gentool -4 -y vars/generic.yml vars/${router}.yml -t templates/afi_specific_filters.j2 -o ${STAGEDIR}/${router}/ipv4_filters.conf
    ./gentool -6 -y vars/generic.yml vars/${router}.yml -t templates/afi_specific_filters.j2 -o ${STAGEDIR}/${router}/ipv6_filters.conf

    ./gentool -4 -y vars/generic.yml vars/${router}.yml vars/members_bgp.yml -t templates/members_bgp.j2 -o ${STAGEDIR}/${router}/members_bgp-ipv4.conf
    ./gentool -6 -y vars/generic.yml vars/${router}.yml vars/members_bgp.yml -t templates/members_bgp.j2 -o ${STAGEDIR}/${router}/members_bgp-ipv6.conf

    ./gentool -4 -y vars/generic.yml vars/${router}.yml vars/transit.yml -t templates/transit.j2 -o ${STAGEDIR}/${router}/transit-ipv4.conf
    ./gentool -6 -y vars/generic.yml vars/${router}.yml vars/transit.yml -t templates/transit.j2 -o ${STAGEDIR}/${router}/transit-ipv6.conf

    ./gentool -4 -y vars/generic.yml vars/${router}.yml vars/scrubbers.yml -t templates/scrubbers.j2 -o ${STAGEDIR}/${router}/scrubber-ipv4.conf
    ./gentool -6 -y vars/generic.yml vars/${router}.yml vars/scrubbers.yml -t templates/scrubbers.j2 -o ${STAGEDIR}/${router}/scrubber-ipv6.conf
    ./gentool -4 -y vars/generic.yml vars/${router}.yml vars/scrubbers.yml -t templates/via_scrubbers_afi.j2 -o ${STAGEDIR}/${router}/via_scrubbers_ipv4.conf
    ./gentool -6 -y vars/generic.yml vars/${router}.yml vars/scrubbers.yml -t templates/via_scrubbers_afi.j2 -o ${STAGEDIR}/${router}/via_scrubbers_ipv6.conf

    # DCG specific stuff
    if [ "${router}" == "dcg-1.router.nl.coloclue.net" ] || [ "${router}" == "dcg-2.router.nl.coloclue.net" ]; then
        ./gentool -4 -t templates/static_routes.j2 -y vars/statics-dcg.yml -o ${STAGEDIR}/${router}/static_routes-ipv4.conf
        ./gentool -6 -t templates/static_routes.j2 -y vars/statics-dcg.yml -o ${STAGEDIR}/${router}/static_routes-ipv6.conf
    # EUNetworks specific stuff
    elif [ "${router}" == "eunetworks-2.router.nl.coloclue.net" ] || [ "${router}" == "eunetworks-3.router.nl.coloclue.net" ]; then
        ./gentool -4 -t templates/static_routes.j2 -y vars/statics-eunetworks.yml -o ${STAGEDIR}/${router}/static_routes-ipv4.conf
        ./gentool -6 -t templates/static_routes.j2 -y vars/statics-eunetworks.yml -o ${STAGEDIR}/${router}/static_routes-ipv6.conf
    fi

    rsync -av blobs/${router}/ ${STAGEDIR}/${router}/
    rsync -av ${BUILDDIR}/rpki/ ${STAGEDIR}/${router}/rpki/

    rsync -av --delete ${BUILDDIR}/*bird* ${STAGEDIR}/${router}/peerings/
    rsync -av --delete ${BUILDDIR}/${router}.ipv4.config ${STAGEDIR}/${router}/peerings/peers.ipv4.conf
    rsync -av --delete ${BUILDDIR}/${router}.ipv6.config ${STAGEDIR}/${router}/peerings/peers.ipv6.conf

    TZ=Etc/UTC date '+# Created: %a, %d %b %Y %T %z' >>  ${STAGEDIR}/${router}/bird.conf
    TZ=Etc/UTC date '+# Created: %a, %d %b %Y %T %z' >>  ${STAGEDIR}/${router}/bird6.conf

done

if [ "${1}" == "push" ]; then

	# sync config to dcg-1 router
	eval $(ssh-agent -t 600)
	ssh-add ~/.ssh/id_rsa_dcg1

    for router in ${routers}; do
        echo "Checking for ${router}"
        /usr/sbin/bird -p -c ${STAGEDIR}/${router}/bird.conf
        /usr/sbin/bird -p -c ${STAGEDIR}/${router}/bird6.conf
    done

    for router in ${routers}; do
        echo uploading for ${router}
        rsync -avH --delete ${STAGEDIR}/${router}/ root@${router}:/etc/bird/
        ssh root@${router} 'chown -R root: /etc/bird; /usr/sbin/birdc configure; /usr/local/bin/birdc6 configure' | sed "s/^/${router}: /"
    done

    # kill ssh-agent
    eval $(ssh-agent -k)

    # update RIPE if new peers are added
    php /opt/coloclue/update-as8283-ripe.php

	# kill ssh-agent
	eval $(ssh-agent -k)
elif [ "${1}" == "check" ]; then

    for router in ${routers}; do
        echo "Checking for ${router}"
        /usr/sbin/bird -p -c ${STAGEDIR}/${router}/bird.conf
        /usr/sbin/bird -p -c ${STAGEDIR}/${router}/bird6.conf
    done
else
    echo "Command '${1}' not supported" 1>&2
	exit 1
fi
