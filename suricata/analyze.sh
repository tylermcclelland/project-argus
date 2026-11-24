#!/bin/bash
# Run Suricata on a pcap file (or a folder of pcaps). Logs go to logs/<name>/.
# Usage: ./analyze.sh pcaps/tcp_syn_attack_small.pcap
cd "$(dirname "$0")"

if [ -z "$1" ] || [ ! -e "pcaps/${1#pcaps/}" ]; then
    echo "Usage: ./analyze.sh pcaps/<file.pcap>   (the file must be in the pcaps folder)"
    exit 1
fi

REL=${1#pcaps/}
REL=${REL%/}
NAME=$(basename "$REL")
NAME=${NAME%.*}
OUT=logs/$NAME

docker exec suricata sh -c "rm -rf '/logs/$NAME' && mkdir -p '/logs/$NAME'" || exit 1

# -r reads a file, -l sets the log folder, -k none ignores bad checksums.
docker exec suricata suricata -r "/pcaps/$REL" -l "/logs/$NAME" -k none >/dev/null 2>&1
STATUS=$?

# Suricata runs as root in the container. Give the files back to the current user.
docker exec suricata chown -R "$(id -u):$(id -g)" "/logs/$NAME"

if [ $STATUS -ne 0 ]; then
    echo "Suricata failed on $REL (exit code $STATUS). Last lines of $OUT/suricata.log:"
    tail -n 5 "$OUT/suricata.log" 2>/dev/null | sed 's/^/  /'
    exit $STATUS
fi

COUNT=$(wc -l 2>/dev/null < "$OUT/fast.log" || echo 0)
echo "Logs written to $OUT/   ($COUNT alerts)"
if [ "$COUNT" -gt 0 ]; then
    echo
    echo "Top alerts:"
    sed -E 's/.*\[\*\*\] \[[0-9:]+\] (.*) \[\*\*\].*/\1/' "$OUT/fast.log" | sort | uniq -c | sort -rn | head -15
fi
