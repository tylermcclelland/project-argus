#!/bin/bash

# This script is to help you quickly install suricata on your Debian OS 
# (tested on Rasberry Pi running Raspberry Pi OS or Raspbian)
#
# The method of install is based on the official suricata documentation and
# the following youtube video: 


# making sure you're system's up to date
echo "Ensuring system is up do date..."

sudo apt update && sudo apt upgrade -y
tmp_exit_code = $?

if [$tmp_exit_code -gt 0]; then
    echo "System up to date"
else
    echo "update and upgrade failed. Exit code: $tmp_exit_code"

