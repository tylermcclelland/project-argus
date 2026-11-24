#!/bin/bash
# Print a summary of one Zeek run.
# Usage: ./summary.sh logs/smallFlows

DIR=${1%/}
if [ -z "$DIR" ] || [ ! -d "$DIR" ]; then
    echo "Usage: ./summary.sh logs/<folder>"
    exit 1
fi
IN=/logs/${DIR#*logs/}

# Run a command inside the container, in this log folder.
z() { docker exec -w "$IN" zeek sh -c "$1" 2>/dev/null; }

# Print a heading and the most common values (top 10 by default).
section() {
    echo
    echo "=== $1 ==="
    local out
    out=$(z "$2" | sort | uniq -c | sort -rn | head -${3:-10})
    if [ -z "$out" ]; then echo "   (none)"; else echo "$out" | column -t -s $'\t'; fi
}

echo "=============================================="
echo "  Zeek summary: $DIR"
echo "=============================================="

if [ -f "$DIR/conn.log" ]; then
    FIRST=$(z "zeek-cut ts < conn.log | sort -n | head -1")
    LAST=$(z "zeek-cut ts < conn.log | sort -n | tail -1")
    echo
    echo "Time range:   $(date -ud @${FIRST%.*} '+%Y-%m-%d %H:%M:%S') to $(date -ud @${LAST%.*} '+%H:%M:%S') UTC"
    echo "Connections:  $(z 'zeek-cut uid < conn.log | wc -l')"
    echo "IP addresses: $(z 'zeek-cut id.orig_h id.resp_h < conn.log | tr "\t" "\n" | sort -u | wc -l')"
fi

[ -f "$DIR/notice.log" ]     && section "Alerts" "zeek-cut note msg < notice.log" 25
[ -f "$DIR/signatures.log" ] && section "Signature matches" "zeek-cut src_addr event_msg < signatures.log"
section "Top clients (started the most connections)" "zeek-cut id.orig_h < conn.log"
section "Top servers (received the most connections)" "zeek-cut id.resp_h < conn.log"
section "Top services" "zeek-cut proto id.resp_p service < conn.log"
[ -f "$DIR/dns.log" ]      && section "Top DNS lookups" "zeek-cut query < dns.log"
[ -f "$DIR/http.log" ]     && section "Top websites (HTTP)" "zeek-cut host < http.log"
[ -f "$DIR/http.log" ]     && section "Top user agents" "zeek-cut user_agent < http.log" 5
[ -f "$DIR/ssl.log" ]      && section "Top websites (HTTPS)" "zeek-cut server_name < ssl.log"
[ -f "$DIR/files.log" ]    && section "File types" "zeek-cut mime_type < files.log"
[ -f "$DIR/software.log" ] && section "Software" "zeek-cut name unparsed_version < software.log"
[ -f "$DIR/weird.log" ]    && section "Unusual traffic (weird.log)" "zeek-cut name < weird.log" 5

echo
echo "=== Largest connections ==="
z "zeek-cut id.orig_h id.resp_h id.resp_p service orig_bytes resp_bytes < conn.log" \
  | awk -F'\t' '{ t=($5=="-"?0:$5)+($6=="-"?0:$6); printf "%d\t%s -> %s:%s (%s)\n", t, $1, $2, $3, $4 }' \
  | sort -rn | head -5 \
  | awk -F'\t' '{ printf "   %8.1f KB   %s\n", $1/1024, $2 }'
echo
