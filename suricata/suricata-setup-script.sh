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

# determine users desired interface (this may just be temporary? maybe we want to be running an instance of Suricata on eth0 and wlan0? for now let them choose)
#echo "Which interface are you wanting to use Suricata on?"
#echo "Type: \"WiFi\" or \"Ethernet\""
#read usr_interface_selection
tmp_bool=0
until [ $tmp_bool -eq 1 ]; do
	echo "Which interface are you wanting to use Suricata on?"
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
#end loop here

# awk added in future to get ip/network addr if users consent?
#TODO: Inital IP grab bug fixed, remove debug prints when done
tmp_bool=0
until [ $tmp_bool -eq 1 ]; do
	read -p "Do you allow us to search for your IP? [yes/no] " usr_consent
	if [[ $usr_consent == "yes" ]]; then
		tmp_bool=1 # to exit initial yes/no check
		echo "Searching for your IP..."
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


# See what configuration the user is wanting to use
echo -e "\nWhat configuration type would you like to install?:"
echo "1. Intrusion Detection System (IDS) - passive/offline setup"
echo "2. Intrusion Prevention System (IPS) - active/online setup"
read -p "Enter your choice (# or abbreviation): " setup_choice

if [[ $setup_choice == 1 || $setup_choice == "IDS" ]]; then
	echo -e "\nYou have chosen to setup IDS, or passive/offline testing."
	echo "Starting IDS configuration..."
	./project-argus/suricata/ids-setup-script.sh
elif [[ $setup_choice == 2 || $setup_choice == "IPS" ]]; then
	echo -e "\nYou have chosen to setup IPS, or active/online testing."
	echo "Starting IPS configuraiton..."
	./project-argus/suricata/ips-setup-script.sh
else
	echo -e "\nYou entered $setup_choice, which is not a valid answer."
fi

