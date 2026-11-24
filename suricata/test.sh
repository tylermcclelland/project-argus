#!/bin/bash
# Run Suricata on every pcap in pcaps/ and print the number of alerts for each.
# Use it to check that Suricata and the rules work, and to compare rule changes.
# Usage: ./test.sh
cd "$(dirname "$0")"

TOTAL=0
printf '%-50s %10s\n' "PCAP" "ALERTS"
for f in pcaps/*; do
    [ -e "$f" ] || continue
    NAME=$(basename "$f"); NAME=${NAME%.*}
    if ./analyze.sh "$f" >/dev/null 2>&1; then
        COUNT=$(wc -l 2>/dev/null < "logs/$NAME/fast.log" || echo 0)
        TOTAL=$((TOTAL + COUNT))
    else
        COUNT="failed"
    fi
    printf '%-50s %10s\n' "${f#pcaps/}" "$COUNT"
done
printf '%-50s %10s\n' "TOTAL" "$TOTAL"
echo
echo "Details for each pcap are in logs/<name>/."
