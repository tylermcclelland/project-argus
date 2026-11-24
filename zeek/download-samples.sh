#!/bin/bash
# Download sample pcap files into pcaps/.
# Usage: ./download-samples.sh
set -e
cd "$(dirname "$0")/pcaps"

get() {
    if [ -f "$1" ]; then
        echo "Already have $1"
    else
        echo "Downloading $1 ..."
        curl -fL --progress-bar -o "$1" "$2"
    fi
}

get smallFlows.pcap https://s3.amazonaws.com/tcpreplay-pcap-files/smallFlows.pcap   # 9 MB
get bigFlows.pcap   https://s3.amazonaws.com/tcpreplay-pcap-files/bigFlows.pcap     # 352 MB
get dns.cap         https://gitlab.com/wireshark/wireshark/-/wikis/uploads/__moin_import__/attachments/SampleCaptures/dns.cap

echo "Done."
