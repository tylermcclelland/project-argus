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

# "basic setup"/configuration
echo "What is your Raspberry Pi's IP address?"
read pi_ip
echo "You said: $pi_ip"
# sudo sed ''/etc/suricata/suricata.yaml