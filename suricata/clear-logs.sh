#!/bin/bash
# Delete live logs to free disk space. Live logs grow without limit on a busy network.
# Usage: ./clear-logs.sh         delete live logs only
#        ./clear-logs.sh --all   delete all logs, including pcap results
set -e
if [ "$1" = "--all" ]; then
    docker exec suricata sh -c 'rm -rf /logs/* && touch /logs/.gitkeep'
else
    docker exec suricata rm -rf /logs/live
fi
docker restart suricata >/dev/null
echo "Logs cleared and Suricata restarted."
