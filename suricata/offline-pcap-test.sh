#!/bin/bash

# This script runs the simple PCAP test offline
#
# The script is intended for a malicious PCAP, such as the TCP-SYN
# DDOS attack from https://data.mendeley.com/datasets/236bd4cjmk/2
#
# It is also highly recommended that the suricata-setup-script.sh
# is run prior to this to ensure the tool is installed, up to date,
# and configured as needed.

echo "Running the offline-pcap-test file..."

echo "Checking if Suricata is running..."
sudo systemctl status suricata | grep 'Active: active (running)'
tmp_exit_code=$?

# Check that Suricata is currently active
if [ $tmp_exit_code -gt 0 ]; then
	echo "Suricata is not currently running. Please run the setup/configuration file."
	break
else

	# Get the location of the file to be run/inspected
	read -p "What is the file path of the PCAP file?: " pcap_loc

	sudo suricata -c /etc/suricata/suricata.yaml -r $pcap_loc -l project-argus/suricata/test-pcap-files/temp-log-storage/
	tmp_exit_code=$?

	if [ $tmp_exit_code -gt 0 ]; then
		echo "Failed to run PCAP file... Exit code: $tmp_exit_code"
	else
		echo "The PCAP file was successfully run!"
		alerts=$(tail -n 2 project-argus/suricata/test-pcap-files/temp-log-storage/suricata.log | head -n 1)
		alert_number=$(grep -o "Alerts: [0-9]\+" <<< "$alerts")
		echo "The number of alerts triggered:"
		echo "    $alert_number"
		echo "For the full log, refer to suricata.log"
	fi
fi
