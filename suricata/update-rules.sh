#!/bin/bash
# Download the latest rules, add your rules from rules/local.rules, and restart Suricata.
# Usage: ./update-rules.sh
set -e
docker exec suricata suricata-update --local /custom-rules
docker restart suricata >/dev/null
echo "Rules updated and Suricata restarted."
