#!/bin/bash

# This script runs the simple PCAP test offline
#
# The script is intended for a malicious PCAP, such as the TCP-SYN
# DDOS attack from https://data.mendeley.com/datasets/236bd4cjmk/2
#
# It is also highly recommended that the suricata-setup-script.sh
# is run prior to this to ensure the tool is installed, up to date,
# and configured as needed.

# arrays to store valid inputs
# NOTE: defining default to 1 and custom to 2
default_arr=({d,D}{e,E}{f,F}{a,A}{u,U}{l,L}{t,T} {o,O}{u,U}{r,R}{s,S} d D 1)
custom_arr=({c,C}{u,U}{s,S}{t,T}{o,O}{m,M} {y,Y}{o,O}{u,U}{r,R}{s,S} c C 2)

echo "Running the offline-pcap-test file..."

echo "Checking if Suricata is running..."
sudo systemctl status suricata | grep 'Active: active (running)'
tmp_exit_code=$?

# Check that Suricata is currently active
if [ $tmp_exit_code -gt 0 ]; then
	echo "Suricata is not currently running. Please run the setup/configuration file."
	break
else
	echo "Suricata is running!"
	#sudo systemctl status suricata | grep 'Active: active (running)'
fi
# On the pcaps i've been testing with (ehich i'm making from recordign my own attacks on my pi) i'm getting a very low number of alerts... Maybe we
# need to merge in some of those rulesets suricata-update provides, or make really specific ones to track exactly what we're looking for.

#NOTE: Getting 0 alerts for the ARP and DHCP tests. There's an error in the ARP test: datalink type 127 not (yet) supported in module PcapFile.
#	   Will investigate more later, had to run to work. I don't know if the files I grabbed are wise to use, I just grabbed what I thought seemed reasonable.

usr_total_alerts=0
baseline_total_alerts=0

# determining if user would like to run their own offline pcap test or use our default test
tmp_bool=0
until [ $tmp_bool -eq 1 ]; do
	#TODO: quick fix, find out how to grab selection withou tbeing case sensitive
	echo "Would you like to run our default tests (that check if Suricata is running as expected), or do you have your own pcaps you want to test?"
	echo "1. default / ours (most common)"
	echo "2. custom / yours"
	read usr_interface_selection
	if [[ ${default_arr[@]} =~ ${usr_interface_selection} || ${custom_arr[@]} =~ ${usr_interface_selection} ]]; then
		tmp_bool=1
		if [[ ${default_arr[@]} =~ ${usr_interface_selection} ]]; then
			echo -e "Okay, going with ours! \n"
			# hardcoding these values (at least for now) as a quick baseline check for the user to see how their config stacks up to the (what should be) default suricata results
			tcp_syn_flood_baseline_alert_num=116819
			port_scan_baseline_alert_num=0
			arp_spoofing_baseline_alert_num=0
			dhcp_attack_baseline_alert_num=0
			dns_attack_baseline_alert_num=0

			((baseline_total_alerts += tcp_syn_flood_baseline_alert_num))
			((baseline_total_alerts += port_scan_baseline_alert_num))
			((baseline_total_alerts += arp_spoofing_baseline_alert_num))
			((baseline_total_alerts += dhcp_attack_baseline_alert_num))
			((baseline_total_alerts += dns_attack_baseline_alert_num))

			echo -e "Starting tests... \n"

			# TCP SYN FLOOD offline pcap test
			echo "running TCP SYN FLOOD attack pcap"
			sudo suricata -c /etc/suricata/suricata.yaml -r suricata/test-pcaps/tcp_syn_attack_small.pcap -l suricata/temp-log-storage/
			tmp_exit_code=$?

			if [ $tmp_exit_code -gt 0 ]; then
				echo "Failed to run PCAP file... Exit code: $tmp_exit_code"
			else
				echo "The TCP SYN flood attack .pcap was successfully run!"
				# alerts=$(tail -n 2 suricata/test-pcap-files/temp-log-storage/suricata.log | head -n 1)
				alert_number=$(grep -oP "Alerts: \K[0-9]+" suricata/temp-log-storage/suricata.log | tail -n 1)
				echo "The number of alerts triggered:"
				echo "    $alert_number"
				echo -e "You should have got ~$tcp_syn_flood_baseline_alert_num alerts."
				echo -e " **NOTE:Depending on your rules you may have a different #. We hardcoded this # based on the default ruleset to act as a baseline."
				echo -e " It is permissible to be within +/- ~15% of our # assuming a default configuration based on our setup script. \n"
				((usr_total_alerts += alert_number))
			fi

			# Port scanning offline pcap test TODO: TO BE IMPLEMENTED OR REPLACED
			#sudo suricata -c /etc/suricata/suricata.yaml -r suricata/test-pcap-files/port-scanning.pcap -l suricata/temp-log-storage/
			#tmp_exit_code=$?

			#if [ $tmp_exit_code -gt 0 ]; then
				#echo "Failed to run PCAP file... Exit code: $tmp_exit_code"
			#else
				#echo "The port scanning attack .pcap was successfully run!"
				# alerts=$(tail -n 2 suricata/test-pcap-files/temp-log-storage/suricata.log | head -n 1)
				#alert_number=$(grep -o "Alerts: [0-9]\+" suricata/temp-log-storage/suricata.log | tail -n 1)
				#echo "The number of alerts triggered:"
				#echo "    $alert_number"
				#echo -e "You should have got ~$port_scan_baseline_alert_num alerts. (depending on your rules. We hardcoded this # based on the default ruleset to act as a baseline) \n"
			#fi

			# ARP spoofing offline pcap test
			sudo suricata -c /etc/suricata/suricata.yaml -r suricata/test-pcaps/daniel_johnny_arp_before_after.pcap -l suricata/temp-log-storage/
			tmp_exit_code=$?

			if [ $tmp_exit_code -gt 0 ]; then
				echo "Failed to run PCAP file... Exit code: $tmp_exit_code"
			else
				echo "The ARP spoofing attack .pcap was successfully run!"
				# alerts=$(tail -n 2 suricata/test-pcap-files/temp-log-storage/suricata.log | head -n 1)
				alert_number=$(grep -oP "Alerts: \K[0-9]+" suricata/temp-log-storage/suricata.log | tail -n 1)
				echo "The number of alerts triggered:"
				echo "    $alert_number"
				echo -e "You should have got ~$arp_spoofing_baseline_alert_num alerts. (depending on your rules. We hardcoded this # based on the default ruleset to act as a baseline) \n"
				((usr_total_alerts += alert_number))
			fi

			# DHCP attack offline pcap test
			sudo suricata -c /etc/suricata/suricata.yaml -r suricata/test-pcaps/dhcp_pcaps -l suricata/temp-log-storage/
			tmp_exit_code=$?

			if [ $tmp_exit_code -gt 0 ]; then
				echo "Failed to run PCAP file... Exit code: $tmp_exit_code"
			else
				echo "The DHCP attack .pcap was successfully run!"
				# alerts=$(tail -n 2 suricata/test-pcap-files/temp-log-storage/suricata.log | head -n 1)
				alert_number=$(grep -oP "Alerts: \K[0-9]+" suricata/temp-log-storage/suricata.log | tail -n 1)
				echo "The number of alerts triggered:"
				echo "    $alert_number"
				echo -e "You should have got ~$dhcp_attack_baseline_alert_num alerts. (depending on your rules. We hardcoded this # based on the default ruleset to act as a baseline) \n"
				((usr_total_alerts += alert_number))
			fi

			# DNS attack offline pcap test
			sudo suricata -c /etc/suricata/suricata.yaml -r suricata/test-pcaps/daniel_johnny_kaminsky_dns.pcap -l suricata/temp-log-storage/
			tmp_exit_code=$?

			if [ $tmp_exit_code -gt 0 ]; then
				echo "Failed to run the DNS attack PCAP file...Exit code: $tmp_exit_code"
			else
				echo "The DNS attack .pcap was successfully run!"
				alert_number=$(grep -oP "Alerts: \K[0-9]+" suricata/temp-log-storage/suricata.log | tail -n 1)
				echo "The number of alerts triggered:"
				echo "    $alert_number"
				echo -e "You should have got ~dns_attack_baseline_alert_num alerts. (depending on your rules. We hardcoded this # based on the default ruleset to act as a baseline.)"
				((usr_total_alerts += alert_number))
			fi

			# Test complete, summarize to user
			echo -e "Test complete! \n"
			echo -e "In total, your config generated $usr_total_alerts alerts. Our baseline config generates $baseline_total_alerts."
			alert_dif=$((usr_total_alerts - baseline_total_alerts))
			if [ $alert_dif -gt 0 ]; then
				echo -e "You generated $alert_dif more alerts than our baseline! "
			elif [ $alert_dif -eq 0 ]; then
				echo -e "You generated the same number of alerts as our baseline! "
			else
				alert_dif=$((alert_dif * -1))
				echo -e "You generated $alert_dif less alerts than our baseline!"
			fi

		elif [[  ${custom_arr[@]} =~ ${usr_interface_selection} ]]; then
			echo -e "Okay, going with yours! Be prepared to provide the path of the pcaps on your system \n"
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

				sudo suricata -c /etc/suricata/suricata.yaml -r $pcap_loc -l suricata/temp-log-storage/
				tmp_exit_code=$?

				if [ $tmp_exit_code -gt 0 ]; then
					echo "Failed to run PCAP file... Exit code: $tmp_exit_code"
				else
					echo "The PCAP file was successfully run!"
					# alerts=$(tail -n 2 suricata/test-pcap-files/temp-log-storage/suricata.log | head -n 1)
					alert_number=$(grep -o "Alerts: [0-9]\+" suricata/temp-log-storage/suricata.log | tail -n 1)
					echo "The number of alerts triggered:"
					echo "    $alert_number"
					echo "For the full log, refer to suricata.log"
				fi
			fi
		fi

	else
		echo "You said: $usr_interface_selection. This is not a valid option."
		echo -e "You must type 'default'/'ours' or 'custom'/'yours'. Trying again... \n"
	fi
done
