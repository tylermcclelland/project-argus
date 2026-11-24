#!/bin/bash
# Run Zeek on a pcap file. Logs go to logs/<pcap-name>/.
# Usage: ./analyze.sh pcaps/smallFlows.pcap
set -e

if [ -z "$1" ] || [ ! -f "pcaps/$(basename "$1")" ]; then
    echo "Usage: ./analyze.sh pcaps/<file.pcap>   (the file must be in the pcaps folder)"
    exit 1
fi

FILE=$(basename "$1")
NAME=${FILE%.*}

docker exec zeek sh -c "rm -rf '/logs/$NAME' && mkdir -p '/logs/$NAME'"

# -C ignores bad checksums, -r reads a file, "local" loads scripts/local.zeek.
docker exec -w "/logs/$NAME" zeek zeek -C -r "/pcaps/$FILE" local

# Zeek runs as root in the container. Give the files back to the current user.
docker exec zeek chown -R "$(id -u):$(id -g)" "/logs/$NAME"

echo "Logs written to logs/$NAME/"
echo
echo "Alerts:"
docker exec -w "/logs/$NAME" zeek sh -c \
    'if [ -f notice.log ]; then zeek-cut note msg < notice.log | sort | uniq -c | sort -rn; else echo "  (none)"; fi'
