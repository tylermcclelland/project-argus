#!/bin/bash

# This script just runs the fast_log in Suricata to make it a little faster :)

echo -e "Starting Suricata's fast.log!\n"

tail -f /var/log/suricata/fast.log
