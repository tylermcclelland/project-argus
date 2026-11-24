#!/bin/bash
# Full demo: create attack traffic, analyze it, and print a summary.
# Usage: ./demo.sh
set -e
cd "$(dirname "$0")"

echo "Step 1: Create test attack traffic on the loopback interface"
docker exec zeek sh /scripts/make-test-traffic.sh
docker exec zeek chown "$(id -u):$(id -g)" /pcaps/test-traffic.pcap
echo

echo "Step 2: Analyze the traffic with Zeek"
./analyze.sh pcaps/test-traffic.pcap
echo

echo "Step 3: Summary"
./summary.sh logs/test-traffic
