#!/usr/bin/env python3

import yaml
import sys
import json
import requests


# A function to get the content of a URL
def download(url):
    try:
        downloaded_file = requests.get(url).text
    except requests.exceptions.RequestException:
        raise

    return downloaded_file


# Load the generic config into a dict
generic_yaml = yaml.safe_load(sys.stdin)

# Dict to store all the ASNs and their info in
asns = {}

# Loop through JSON URLs
url_counter = 0
for json_url in generic_yaml['rpki_json_urls']:
    # Increase the URL counter, so we can count how many files there have been
    # downloaded
    url_counter += 1

    # Download URL
    try:
        json_raw = download(json_url)
    except requests.exceptions.RequestException:
        print("Downloading", json_url, " failed.", file=sys.stderr)
        continue
    # Parse json into dict
    try:
        roas = json.loads(json_raw)
    except Exception:
        print("Parsing JSON from", json_url, "failed.", file=sys.stderr)
        continue

    # Loop through the ROAs in the file
    for roa in roas['roas']:
        # Remove any potential 'AS' text from the ASN
        asn = roa['asn'].replace('AS', '')
        if asn not in asns:
            asns[asn] = {}
        prefix_info = roa['prefix'], roa['maxLength']
        if prefix_info not in asns[asn]:
            asns[asn][prefix_info] = roa['ta']

# Loop through all the ASNs info and convert it to a dict rtrsub knows
roas = {}
roas['roas'] = []
for asn in asns:
    for prefix_info, ta in asns[asn].items():
        roa = {}
        roa['asn'] = asn
        roa['prefix'] = prefix_info[0]
        roa['maxLength'] = prefix_info[1]
        roa['ta'] = ta
        roas['roas'].append(roa)

if len(roas['roas']) == 0:
    print('Building a list of ROAs failed, exiting.', file=sys.stderr)
    sys.exit(1)

# Convert roa info to JSON
json_output = json.JSONEncoder().encode(roas)
# Write json into file
roa_file = open('/tmp/kees-roas.json', 'w')
roa_file.write(json_output)
roa_file.close()
