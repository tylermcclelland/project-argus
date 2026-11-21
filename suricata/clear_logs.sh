#!/bin/bash

# Quickly clears logs to clear storage space/to make more clear for demos
# When restarting Suricata, it will automatically recreate these files
# Temporary way to clear out logs until we determine what method we want
# to use to cycle through logs and free up disk space

echo "Stopping Suricata..."

sudo systemctl stop suricata
tmp_exit_code=$?

if [ $tmp_exit_code -gt 0 ]; then
	echo -e "Suricata failed while terminating. Exit code: $tmp_exit_code\n"
else
	echo -e "Suricata has been stopped successfully.\n"
fi

echo "Clearing logs from /var/log/suricata/..."

sudo rm /var/log/suricata/fast.log
sudo rm /var/log/suricata/eve.json
sudo rm /var/log/suricata/stats.log
sudo rm /var/log/suricata/suricata.log

echo -e "Logs have been cleared from the Suricata logs.\n"

echo "Clearing logs from project-argus/suricata/temp-log-storage/..."

sudo rm suricata/temp-log-storage/fast.log
sudo rm suricata/temp-log-storage/eve.json
sudo rm suricata/temp-log-storage/stats.log
sudo rm suricata/temp-log-storage/suricata.log

echo -e "Logs have been cleared in the Project Argus temp-log-storage.\n"

echo "Starting Suricata..."

sudo systemctl start suricata
tmp_exit_code=$?

if [ $tmp_exit_code -gt 0 ]; then
	echo "Suricata failed to start. Exit code: $tmp_exit_code"
else
	echo "Suricata is now running!"
fi
