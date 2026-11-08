#!/bin/bash

# This script is to help you quickly install suricata on your Debian OS 
# (tested on Rasberry Pi running Raspberry Pi OS or Raspbian)
#
# The method of install is based on the official suricata documentation and
# the following youtube video: https://www.youtube.com/watch?v=GrT64MH2CIM


# making sure you're system's up to date
echo "Ensuring system is up do date..."

sudo apt update && sudo apt upgrade -y
tmp_exit_code=$?

if [ $tmp_exit_code -gt 0 ]; then
    echo "update and upgrade failed. Exit code: $tmp_exit_code"
else
    echo "System up to date!"
fi

#actual Suricata install
echo "Installing Suricata..."

sudo apt-get install suricata -y 
tmp_exit_code=$?

if [ $tmp_exit_code -gt 0 ]; then
    echo "Suricata install failed... Exit code: $tmp_exit_code"
else
    echo "Suricata was installed!"
    #show version 
    echo "Version: "
    sudo suricata --build-info | head -n 1 #in my --build-info output, version was on line one so -n 1 TODO: change this to a grep?

    #see if suricata is running
    echo "Seeing if suricata is running..."
    sudo systemctl status suricata | grep 'Active: active (running)'
    tmp_exit_code=$?

    if [ $tmp_exit_code -gt 0 ]; then
        echo "Suricata not running. Starting Suricata..."
        sudo systemctl enable --now suricata
    else
        echo "Suricata is running!"
    fi

fi

# "basic setup"/configuration
# the -i.bak flag should make a backup file before editing/changing the file

echo -e "\nStarting basic configuration...\n"

# Check if iptables installed, install if not and delete all NFQUEUE rules (if any) to avoid denying pkts

if ! command -v iptables &> /dev/null; then
	echo "iptables not installed...installing for future use."
	sudo apt update && sudo apt install iptables
	tmp_exit_code=$?
	if [ $tmp_exit_code -gt 0 ]; then
		echo -e "iptables had an issue installing... Exit code: $tmp_exit_code\n"
	else
		echo -e "iptables was successfully installed!\n"
	fi
else
	# if already set installed, delete any rules that were set up
	echo "iptables is already installed, deleting previous NFQUEUE rules..."
	sudo iptables -F INPUT
	sudo iptables -F OUTPUT
	echo -e "All INPUT/OUTPUT rules have been flushed!\n"
fi

# determine users desired interface (this may just be temporary? maybe we want to be running an instance of Suricata on eth0 and wlan0? for now let them choose)
#NOTE: my pi says eth0 is down. should we go through the trouble of briging up the eth0 interface on a users machine if they
# 	   don't have it set up? or just tell them "You haven't yet brought up the eth0 interface on your machine... WiFi instead?? [y/n]"
tmp_bool=0
until [ $tmp_bool -eq 1 ]; do
	#TODO: quick fix, find out how to grab selection withou tbeing case sensitive
	echo "Type: \"WiFi\" or \"Ethernet\""
	read usr_interface_selection
	if [[ $usr_interface_selection == "WiFi" || $usr_interface_selection == "Ethernet" ]]; then
		echo "Okay, starting setup on $usr_interface_selection..."
		tmp_bool=1
	else
		echo "You said: $usr_interface_selection. This is not a valid option."
		echo "You must type \"WiFi\" or \"Ethernet\". Trying again..."
	fi
done

# awk added in future to get ip/network addr if users consent?
#TODO: Inital IP grab bug fixed, remove debug prints when done
tmp_bool=0
ip_found=0
until [ $tmp_bool -eq 1 ]; do
	read -p "Do you allow us to search for your IP? [yes/no] " usr_consent
	if [[ $usr_consent == "yes" ]]; then
		tmp_bool=1 # to exit initial yes/no check
		echo "Starting search for your IP..."

		# apparently ifconfig is depricated, their manpage says to use "ip"... Leaving ifconfig setup/grab code just incase
		# i have problems w "ip" TODO: remove ifconfig code if it's pointless

		#echo "Checking ifconfig installation"
		#sudo ifconfig --version #checking if user has ifconfig
		echo "Checking ip installation"
		sudo ip -V #checking if user has ip
		tmp_exit_code=$?
		if [ $tmp_exit_code -eq 0 ]; then
			#echo "ifconfig installation verified"
			echo "ip installation verified"
		else
			#echo "ifconfig not found"
			#sudo apt install net-tools
			echo "ip (from iproute2) not found... Installing"
			sudo apt install iproute2
			tmp_exit_code=$?
			if [ $tmp_exit_code -eq 0 ]; then
				#echo "net-tools installed! (ifconfig is contained within net-tools)"
				echo "iproute2 installed! (ip tool is contained within iproute2)"
				sudo ip -V
			else
				#echo "Unable to install ifconfig"
				echo "Unable to install ip :("
				echo "You'll have to give your IP"
			fi
		fi
		if [[ $usr_interface_selection == "WiFi" ]]; then
			#implement wifi ip grab
			#echo "wlan0 ip grab not yet implemented..."
			#wifi_ip=ifconfig | tail -n 7 | head -n 1 #kind of hacky but I think ifconfig consistently prints on the same line numbers for any ifconfig version that the user will likely have TODO: investigate a better way to grab ip
			pi_ip=$(sudo ip addr show wlan0 | grep "inet" | cut -c 10-21)
			echo "WiFi: $pi_ip"
			sudo ip link set wlan0 promisc on
		elif [[ $usr_interface_selection == "Ethernet" ]]; then
			#implement eth0 ip grab
			#echo "eth0 ip grab not yet implemented..."
			#eth_ip=ifconfig | head -n 2 | tail -n 1
			#eth_ip=
			#echo "ETH: $eth_ip"
			sudo ip addr show eth0
			echo "Ethernet ip grab not yet implemented"
		fi
		# sudo ifconfig | grep "wlan0"

	#echo "HERE 1"
	elif [[ $usr_consent == "no" ]]; then
		#echo "HERE 2"
		tmp_bool=1 # to exit initial yes/no check
		tmp_bool_inner=0
		until [ $tmp_bool_inner -eq 1 ]; do
			#echo "HERE 3"
			read -p "Please provide your IP: " pi_ip
			read -p "You said $pi_ip. Is that right? [yes/no]" usr_consent
			if [[ $usr_consent == "yes" ]]; then
				#echo "HERE 4"
				tmp_bool_inner=1
				echo "IP:$pi_ip stored."
				continue
			elif [[ $usr_consent == "no" ]]; then
				#echo "HERE 5"
				tmp_bool_inner=0
				echo "Okay, lets try again..."
			fi
		done
	else
		tmp_bool=0 #probably not necessary, just ensuring loop functios properly
		echo "You must type \"yes\" or \"no\". Try again..."
	fi
done

# the -i.bak flag should make a backup file before editing/changing the file
# testing on a fake yaml file

target_string="HOME_NET:.*"
replacement_string="HOME_NET: \"[$pi_ip/24]\""

# UPDATE TO REAL .YAML IN FUTURE :)
sudo sed -i.bak "0,/$target_string/s|$target_string|$replacement_string|" suricata_mock.yaml
tmp_exit_code=$?

if [ $tmp_exit_code -gt 0 ]; then
	echo "IP was unable to be updated. Exit code: $tmp_exit_code"
	exit 1
else
	echo "IP address has been updated in suricata.yaml!"
fi

# Make sure that the rules file is up to date/the correct file path
current_rule_path=$(grep "default-rule-path" suricata_mock.yaml)
echo -e "\nYour default rule path is currently set to: \n$current_rule_path"

read -p "The default rules file is /etc/suricata/rules. Does this match your file location? [yes/no]: " rule_input

if [[ $rule_input == "yes" ]]; then
	echo "You entered 'yes', checking that the default-rule-path matches..."
	# update to real file in future :)
	if grep -q "default-rule-path: /etc/suricata/rules" suricata_mock.yaml; then
		echo -e "Default rule path matches! Continuing setup...\n"
	else
		def_rule_path="default-rule-path:.*"
		echo "You entered yes, but your default rule path currently set to:"
		echo $def_rule_path
		read -p "Would you like to update to the default? [yes/no]: " update_input
		if [[ $update_input == "yes" ]]; then
			update_rule_path="default-rule-path: /etc/suricata/rules"
			sudo sed -i.bak "0,/$def_rule_path/s|$def_rule_path|$update_rule_path|" suricata_mock.yaml
			echo "The rule path has been updated! Restarting Suricata to update rule path..."
			sudo systemctl restart suricata
			echo "Suricata has been restarted! Continuing setup..."
		else
			echo -e "You entered 'no', the rule path will not be updated. Continuing setup..."
		fi
	fi
else
	read -p "You entered 'no', would you like to update the file location [yes/no]: " file_update
	if [[ $file_update == "yes" ]]; then
		echo "You entered 'yes', updating default-rule-path..."
		def_rule_path="default-rule-path:.*"
		update_rule_path="default-rule-path: /etc/suricata/rules"
                sudo sed -i.bak "0,/$def_rule_path/s|$def_rule_path|$update_rule_path|" suricata_mock.yaml
		echo "Rule path has been succesfully updated! Restarting Suricata to update rule path..."
		sudo systemctl restart suricata
		echo "Suricata has been restarted! Continuing setup..."
	else
		echo "You entered 'no', the default-rule-path will not be updated. Continuing setup..."
	fi
fi

# Update the Suricata rules before starting

# get the rule path without hte beginning
rule_path=$(grep -m 1 "default-rule-path:" suricata_mock.yaml | awk '{print $2}')
echo -e "\nUpdating Suricata rules..."
sudo suricata-update -o $rule_path
tmp_exit_code=$?
if [ $tmp_exit_code -gt 0 ]; then
	echo "Suricata has failed to update and test your rules. Exit code: $tmp_exit_code"
else
	echo "Suricata has successfully updated and tested your rules!"
fi

# See what configuration the user is wanting to use
echo -e "\nWhat configuration type would you like to install?:"
echo "1. Intrusion Detection System (IDS)"
echo "2. Intrusion Prevention System (IPS) - 'advanced' mode"
read -p "Enter your choice (# or abbreviation): " setup_choice

if [[ $setup_choice == 1 || $setup_choice == "IDS" ]]; then
# Check if iptables installed, install if not and delete all NFQUEUE rules (if any) to avoid denying pkts

	if ! command -v iptables &> /dev/null; then
        	echo "iptables not installed...installing for future use."
        	sudo apt update && sudo apt install iptables
        	tmp_exit_code=$?
        	if [ $tmp_exit_code -gt 0 ]; then
                	echo -e "iptables had an issue installing... Exit code: $tmp_exit_code\n"
        	else
                	echo -e "iptables was successfully installed!\n"
        	fi
        fi
	
	# if already set installed, delete any rules that were set up
        sudo iptables -F INPUT
        sudo iptables -F OUTPUT
	
	echo -e "\nYou have chosen to setup Intrusion Detection System (IDS)."
	echo "Starting IDS configuration..."
	./project-argus/suricata/ids-setup-script.sh

elif [[ $setup_choice == 2 || $setup_choice == "IPS" ]]; then
	echo -e "\nYou have chosen to setup Intrustion Prevention System (IPS)."
	echo "Starting IPS configuraiton..."
	./project-argus/suricata/ips-setup-script.sh
else
	echo -e "\nYou entered $setup_choice, which is not a valid answer."
fi

