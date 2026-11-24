#!/bin/bash
# Watch a network interface live with Zeek. Press Ctrl+C to stop.
# Usage: ./live.sh eth0
set -e

if [ -z "$1" ]; then
    echo "Usage: ./live.sh <interface>"
    echo
    echo "Interfaces on this computer:"
    docker exec zeek ip -br link | awk '{print "  " $1}' | sed 's/@.*//'
    exit 1
fi

IFACE=$1
DIR="live-$IFACE-$(date +%Y%m%d-%H%M%S)"

docker exec zeek mkdir -p "/logs/$DIR"
echo "Listening on $IFACE. Logs go to logs/$DIR/. Press Ctrl+C to stop."

docker exec -it -w "/logs/$DIR" zeek zeek -C -i "$IFACE" local || true

docker exec zeek chown -R "$(id -u):$(id -g)" "/logs/$DIR"
echo "Stopped. Logs are in logs/$DIR/"
