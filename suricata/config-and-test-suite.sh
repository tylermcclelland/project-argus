#!/bin/bash

# This script runs the configuration and all current tests that have
# been configured for Suricata.

echo "Running the Suricata setup script..."

./project-argus/suricata/suricata-setup-script.sh
tmp_exit_code=$?

# Check there weren't config issues
if [ $tmp_exit_code -gt 0 ]; then
	echo "There was an issue in the setup script. Please try again."
	echo "Exit code: $tmp_exit_code"
	break
else
	echo -e "\nRunning the offline PCAP test..."
	./project-argus/suricata/offline-pcap-test.sh
	echo -e "Offline PCAP test complete.\n"
fi
