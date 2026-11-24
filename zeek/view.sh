#!/bin/bash
# Show a Zeek log as a table with readable dates.
# Usage:
#   ./view.sh logs/smallFlows/conn.log               default columns
#   ./view.sh logs/smallFlows/conn.log all           every column
#   ./view.sh logs/smallFlows/http.log ts host uri   chosen columns
# Use the arrow keys to scroll, / to search, and q to quit.

if [ -z "$1" ] || [ ! -f "$1" ]; then
    echo "Usage: ./view.sh logs/<folder>/<name>.log [all | column names...]"
    exit 1
fi

LOG=$1
shift
TYPE=$(basename "$LOG" .log)

# Default columns for common logs.
if [ $# -gt 0 ]; then
    COLS="$*"
else
    case "$TYPE" in
        conn)           COLS="ts id.orig_h id.orig_p id.resp_h id.resp_p proto service duration orig_bytes resp_bytes conn_state" ;;
        dns)            COLS="ts id.orig_h id.resp_h query qtype_name rcode_name answers" ;;
        http)           COLS="ts id.orig_h id.resp_h method host uri status_code user_agent" ;;
        ssl)            COLS="ts id.orig_h id.resp_h id.resp_p version server_name established" ;;
        notice)         COLS="ts note msg src dst" ;;
        signatures)     COLS="ts src_addr dst_addr dst_port sig_id event_msg" ;;
        files)          COLS="ts source mime_type filename total_bytes md5" ;;
        weird)          COLS="ts id.orig_h id.resp_h name" ;;
        software)       COLS="ts host software_type name unparsed_version" ;;
        known_hosts)    COLS="ts host" ;;
        known_services) COLS="ts host port_num port_proto service" ;;
        ssh)            COLS="ts id.orig_h id.resp_h auth_success client server" ;;
        dhcp)           COLS="ts client_addr server_addr mac host_name assigned_addr" ;;
        x509)           COLS="ts certificate.subject certificate.issuer certificate.not_valid_after" ;;
        *)              COLS="all" ;;
    esac
fi

if [ "$COLS" = "all" ]; then
    COLS=$(grep -m1 '^#fields' "$LOG" | cut -f2-)
fi

# zeek-cut runs inside the container, where logs/ is mounted at /logs.
IN_CONTAINER="/logs/${LOG#*logs/}"

{
    echo "$COLS" | tr ' ' '\t'
    docker exec zeek sh -c "zeek-cut -D '%Y-%m-%d %H:%M:%S' $COLS < '$IN_CONTAINER'"
} | column -t -s $'\t' \
  | if [ -t 1 ]; then less -S; else cat; fi
