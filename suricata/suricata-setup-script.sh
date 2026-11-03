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

# used by debian package install in suricata docs, youtube video used 'sudo apt install suricata -y'
# not sure if that matters, noting for potential debugging 
# TODO: remove comment after verifying it doesn't matter
sudo apt-get install suricata -y 
tmp_exit_code=$?

if [ $tmp_exit_code -gt 0 ]; then
    echo "Suricata install failed... Exit code: $tmp_exit_code"
else
    echo "Suricata was installed!"
    #show version 
    echo "Version: "
    sudo suricata --build-info | head -n 1 #in my --build-info output, version was on line one so -n 1

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

# "basic setup"/configuration
#echo "What is your Raspberry Pi's IP address?"
#read pi_ip
#echo "You said: $pi_ip"
# sudo sed ''/etc/suricata/suricata.yaml
