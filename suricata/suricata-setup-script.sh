#!/bin/bash

# This script is to help you quickly install suricata on your Debian OS 
# (tested on Rasberry Pi running Raspberry Pi OS or Raspbian)
#
# The method of install is based on the official suricata documentation and
# the following youtube videos: 
# https://www.youtube.com/watch?v=GrT64MH2CIM , https://www.youtube.com/watch?v=8Q3Nhyvh-1I&t=2046s , https://www.youtube.com/watch?v=UXKbh0jPPpg

#NOTE: IT IS ASSUMED THIS WILL BE RUN FROM REPO ROOT (meaning project-argus)

# arrays to store valid inputs. Surely there's a better way but this works, saves extra code, and makes sense. Replace if you find a better way
# TODO: there should be 2^n (n is num of characters) combiniations per word so i'm missing some, low on time so will fix that later. Plenty of options for now...
# NOTE: defining yes to always be 1 in a prompt and 2 to always be no
yes_arr=(YES YEs Yes yes yEs yES yeS y Y 1) 
no_arr=(NO No nO no n N 2)
# NOTE: defining Wifi to always be 1 in a prompt and 2 to always be Ethernet
wifi_arr=(WIFI WIFi WIfi Wifi wifi wifI wiFI wIFI wlan0 1) 
eth_arr=(Eth Ethernet eth0 ethernet ETH 2)
# NOte: defining IDS as 1 and IPS as 2
ids_arr=(IDS IDs Ids ids iDS idS iDs IdS 1)
ips_arr=(IPS IPs Ips ips iPS ipS iPs IpS 2)



# making sure you're system's up to date
echo "Ensuring system is up to date..."

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
	sudo suricata --build info | grep -m 1 "version"

    #see if suricata is running
    echo "Seeing if suricata is running..."
    sudo systemctl status suricata | grep 'Active: active (running)'
    tmp_exit_code=$?

    if [ $tmp_exit_code -gt 0 ]; then
        echo "Suricata not running. Starting Suricata..."
        sudo systemctl enable --now suricata
    else
        echo -e "Suricata is running! \n"
    fi

fi

# ensuring suricata has a default ruleset loaded (as suricata-update will place a suricata.rules in var/lib/suricata/rules)
echo -e "Loading a default ruleset..."
#suricata-update should've been downloaded when we installed Suricata, but adding a quick check
sudo suricata-update -V
tmp_exit_code=$?
if [ $tmp_exit_code -gt 0 ]; then
	echo "suricata-update not found"
	echo "installing suricata-update"
	sudo suricata-update
	echo "suricata-update installed"
	sudo suricata-update -V
else
	echo "suricata-update found!"
fi

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
# NOTE: my pi says eth0 is down. should we go through the trouble of briging up the eth0 interface on a users machine if they
# 	   don't have it set up? or just tell them "You haven't yet brought up the eth0 interface on your machine... WiFi instead?? [y/n]"

tmp_bool=0
until [ $tmp_bool -eq 1 ]; do
	# TODO: quick fix, find out how to grab selection without being case sensitive 
	# UPDATE: implementations look convoluted on bash forums... kicking this can down the road and 
	#         just assuming they'll provide one of the three options: num, type it upper or lower case... still TODO!
	echo "Which interface do you want to setup Suricata on?"
	echo "1: WiFi (most common)"
	echo "2: Ethernet (if you connect to your router via a LAN cable)"
	read usr_interface_selection

	if [[ ${wifi_arr[@]} =~ ${usr_interface_selection} ]]; then
		tmp_bool=1
		echo -e "Okay, starting setup on WiFi... \n"
		# updating the .yaml to use the interface the user specified
		# the -i.bak flag should make a backup file before editing/changing the file
		# testing on a fake yaml file

		target_string="- interface:.*"
		replacement_string="- interface: wlan0"
		# UPDATE TO REAL .YAML IN FUTURE :)
		sudo sed -i.bak "0,/$target_string/s|$target_string|$replacement_string|" suricata/suricata_mock.yaml
		tmp_exit_code=$?
		if [ $tmp_exit_code -gt 0 ]; then
			echo -e "Your selected interface was unable to be updated in the configuration file. Exit code: $tmp_exit_code \n"
			exit 1
		else
			#echo "From /etc/suricata/suricata.yaml: " //placeholder for final script
			#cat /etc/suricata/suricata.yaml | grep "interface:" | head -n 1 //placeholder for final script
			echo "From suricata/suricata_mock.yaml: "
			cat suricata/suricata_mock.yaml | grep "interface:" | head -n 1
			echo -e "Your selected interface has been updated in suricata.yaml! \n"
		fi
	elif [[ ${eth_arr[@]} =~ ${usr_interface_selection} ]]; then
		tmp_bool=1
		echo -e "Okay, starting setup on Ethernet... \n"
		target_string="- interface:.*"
		replacement_string="- interface: eth0"
		# UPDATE TO REAL .YAML IN FUTURE :)
		sudo sed -i.bak "0,/$target_string/s|$target_string|$replacement_string|" suricata/suricata_mock.yaml
		tmp_exit_code=$?
		if [ $tmp_exit_code -gt 0 ]; then
			echo -e "Your selected interface was unable to be updated in the configuration file. Exit code: $tmp_exit_code \n"
			exit 1
		else
			#echo "From /etc/suricata/suricata.yaml: " //placeholder for final script
			#cat /etc/suricata/suricata.yaml | grep "interface:" | head -n 1 //placeholder for final script
			echo "From suricata/suricata_mock.yaml: "
			cat suricata/suricata_mock.yaml | grep "interface:" | head -n 1
			echo -e "Your selected interface has been updated in suricata.yaml! \n"
		fi
	else
		echo "You said: $usr_interface_selection. This is not a valid option."
		echo -e "You must type \"WiFi\" or 0, \"Ethernet\" or 1. Trying again... \n"
	fi
done

tmp_bool=0
ip_found=0 
until [ $tmp_bool -eq 1 ]; do
	echo "Do you allow us to search for your IP?"
	echo "1: Yes (Easiest and most common) "
	echo "2: No (You will have to go find the correct IP yourself)"
	read usr_consent
	if [[ ${yes_arr[@]} =~ ${usr_consent} ]]; then
		tmp_bool=1 # to exit initial yes/no check
		echo "Starting search for your IP..."
		echo "Checking ip installation"
		sudo ip -V #checking if user has ip
		tmp_exit_code=$?
		if [ $tmp_exit_code -eq 0 ]; then
			echo "ip installation verified"
		else
			echo "ip (from iproute2) not found... Installing"
			sudo apt install iproute2
			tmp_exit_code=$?
			if [ $tmp_exit_code -eq 0 ]; then
				echo "iproute2 installed! (ip tool is contained within iproute2)"
				sudo ip -V
			else
				echo "Unable to install iproute2 :("
				echo "You'll have to give your IP"
			fi
		fi
		if [[ ${wifi_arr[@]} =~ ${usr_interface_selection} ]]; then
			#implement wifi ip grab
			pi_ip=$(sudo ip addr show wlan0 | grep -m 1 "inet" | cut -c 10-21)
			echo -e "WiFi: $pi_ip \n"
			sudo ip link set wlan0 promisc on
		elif [[ ${eth_arr[@]} =~ ${usr_interface_selection} ]]; then
			#implement eth0 ip grab 
			# NOTE: ETH IP grab not yet implemented because we're assuming a user w/ an out of the box system (Morgan correct me if i'm wrong!) and on my 
			# pi, eth is "down" and not setup (not showing an ipv4 addr), thus it is TBD if we are going to set it up for them in this script, or just 
			# tell them they need to go set it up

			#pi_ip=$(sudo ip addr show eth0 | grep -m 1 "inet" | cut -c 10-21)
			#echo "ETH: $eth_ip"
			sudo ip addr show eth0
			echo -e "Ethernet ip grab not yet implemented \n"
		fi

	elif [[ ${no_arr[@]} =~ ${usr_consent} ]]; then
		tmp_bool=1 # to exit initial yes/no check
		tmp_bool_inner=0 # to exit on users conformatino of their IP
		until [ $tmp_bool_inner -eq 1 ]; do
			#defining IP addr as an IPv4 addr. Confirming we have a valid IP
			read -p "Please provide your IP: " pi_ip
			# TODO: dealing with a bug where the $pi_ip check is accepting IP addresses it shouldn't... 
			#		it still accepts valid IPs so I'm not commenting it out. Just note it isn't stopping invalid IPs rgiht now :(
			if [[ $pi_ip =~ [0-255\.0-255\.0-255\.0-255] ]]; then
				#tmp_bool_inner=1
				read -p "You said: $pi_ip is that right? [yes/no]: " usr_consent 
				if [[ ${yes_arr[@]} =~ ${usr_consent} ]]; then
					tmp_bool_inner=1
					echo -e "IP: $pi_ip stored. \n"
					continue
				elif [[ ${no_arr[@] =~ ${usr_consent}} ]]; then	
					tmp_bool_inner=0
					echo -e "Okay, lets try again...\n"
				fi
			else
				ip_found=0
				echo "You must provide an IPv4 address of the form: 0.0.0.0"
				echo -e "You provided: $pi_ip ... Try again \n"
			fi
		done
	else
		tmp_bool=0 #probably not necessary, just ensuring loop functios properly
		echo -e "You must type \"yes\" or 1,  \"no\" or 2. Try again... \n"
	fi
done

# the -i.bak flag should make a backup file before editing/changing the file
# testing on a fake yaml file

target_string="HOME_NET:.*"
replacement_string="HOME_NET: \"[$pi_ip/24]\""

# UPDATE TO REAL .YAML IN FUTURE :)
sudo sed -i.bak "0,/$target_string/s|$target_string|$replacement_string|" suricata/suricata_mock.yaml
tmp_exit_code=$?

if [ $tmp_exit_code -gt 0 ]; then
	echo "IP was unable to be updated. Exit code: $tmp_exit_code"
	exit 1
else
	echo "IP address has been updated in suricata.yaml!" #TODO: eventually (not necessary for the demo) we should probably put a check here for a valid IP such that I cant say my IP is "potato"
fi

# Make sure that the rules file is up to date/the correct file path
current_rule_path=$(grep "default-rule-path" suricata/suricata_mock.yaml)
echo -e "\nYour default rule path is currently set to: \n$current_rule_path"

tmp_bool=0
until [ $tmp_bool -eq 1 ]; do
	read -p "The default rules file is /var/lib/suricata/rules. Does this match your file location? [y/n]: " rule_input
	if [[ ${yes_arr[@]} =~ ${rule_input} ]]; then
		tmp_bool=1
		echo "You entered 'yes', checking that the default-rule-path matches..."
		# update to real file in future :)
		if grep -q "default-rule-path: /var/lib/suricata/rules" suricata/suricata_mock.yaml; then
			echo -e "Default rule path matches! Continuing setup...\n"
		else
			def_rule_path="default-rule-path:.*"
			echo "You entered yes, but your default rule path currently set to:"
			echo $def_rule_path
			tmp_inner_bool=0
			until [ $tmp_inner_bool -eq 1 ]; do
				read -p "Would you like to update to the default? [y/n]: " update_input
				if [[ ${yes_arr[@]} =~ ${update_input} ]]; then
					tmp_inner_bool=1
					update_rule_path="default-rule-path: /var/lib/suricata/rules"
					sudo sed -i.bak "0,/$def_rule_path/s|$def_rule_path|$update_rule_path|" suricata/suricata_mock.yaml
					echo "The rule path has been updated! Restarting Suricata to update rule path..."
					sudo systemctl restart suricata
					echo "Suricata has been restarted! Continuing setup..."
				elif [[ ${no_arr[@]} =~ ${update_input} ]]; then
					tmp_inner_bool=1
					echo -e "You entered 'no', the rule path will not be updated. Continuing setup..."
				else
					echo -e "You entered $update_input, which is not a valid input. Please try again: "
					read -p "Would you like to update to the default? [y/n]: " update_input
				fi
			done
		fi
	elif [[ ${no_arr[@]} =~ ${rule_input} ]]; then
		tmp_bool=1
		read -p "You entered 'no', would you like to update the file location [y/n]: " file_update
		tmp_inner_bool=0
		until [ $tmp_inner_bool -eq 1 ]; do
			if [[ ${yes_arr[@]} =~ ${file_update} ]]; then
				tmp_inner_bool=1
				echo "You entered 'yes', updating default-rule-path..."
				def_rule_path="default-rule-path:.*"
				update_rule_path="default-rule-path: /var/lib/suricata/rules"
                		sudo sed -i.bak "0,/$def_rule_path/s|$def_rule_path|$update_rule_path|" suricata/suricata_mock.yaml
				echo "Rule path has been succesfully updated! Restarting Suricata to update rule path..."
				sudo systemctl restart suricata
				echo "Suricata has been restarted! Continuing setup..."
			elif [[ ${no_arr[@]} =~ ${file_update} ]]; then
				tmp_inner_bool=1
				echo "You entered 'no', the default-rule-path will not be updated. Continuing setup..."
			else
				echo "You entered $file_update, which is not a valid input. Please try again: "
				read -p "You entered 'no', would you like to update the file location [y/n]: " file_update
			fi
		done
	else
		echo "You entered $rule_input, which is not a valid input. Please try again: "
		read -p "The default rules file is /var/lib/suricata/rules. Does this match your file location? [y/n]: " rule_input
	fi
done

# Check if using custom rules
echo "The current rule-files being used at runtime:"
# Print not just the first 2 lines
sed -n '/^rule-files:/,/^[^ ]/p' suricata/suricata_mock.yaml

read -p "The default is to only use the suricata.rules, does this match your setup? [y/n]: " custom_input

tmp_bool=0
until [ $tmp_bool -eq 1 ]; do
	if [[ ${yes_arr[@]} =~ ${custom_input} ]]; then
		tmp_bool=1
		# check its only Suricata.rules
		if [[ $(grep -A 2 '^rule-files:' suricata/suricata_mock.yaml | grep '^  - ' | grep -vc '^  - suricata\.rules$') -eq 0 ]]; then
			echo "rule-files category matches! Continuing setup..."
		else
			echo "You entered 'yes', but your rule-files is currently set up as:"
			sed -n '/^rule-files:/,/^[^ ]/p' suricata/suricata_mock.yaml
			read -p "Would you like to update to the default? [y/n]: " update_rules

			tmp_inner_bool=0

			until [ $tmp_inner_bool -eq 1]; do
				if [[ ${yes_arr[@]} =~ ${update_rules} ]]; then
					tmp_inner_bool=1
					echo "Updating rule files..."
					sed -i '/^rule-files:/,/^[^ ]/{/^  - suricata\.rules$/!{/^  - /d;}}' suricata/suricata_mock.yaml
					# debug
					sed -n '/^rule-files:/,/^[^ ]/p' suricata/suricata_mock.yaml
					echo "The rule files have been updated! Continuing setup..."
				elif [[ ${no_arr[@]} =~ ${update_rules} ]]; then
					tmp_inner_bool=1
					echo "You entered 'no', your rule-files will not be updated. Continuing setup..."
				else
					echo "You entered $update_rules, which is not a valid input. Please try again: "
					echo "You entered 'yes', but your rule-files is currently set up as:"
		                        sed -n '/^rule-files:/,/^[^ ]/p' suricata/suricata_mock.yaml
                		        read -p "Would you like to update to the default? [y/n]: " update_rules
				fi
			done
		fi
	elif [[ ${no_arr[@]} =~ ${custom_input} ]]; then
		tmp_bool=1
		read -p "You entered 'no', would you like to remove the custom path file? [y/n]: " remove_input

		tmp_inner_bool=0
		until [ $tmp_inner_bool -eq 1 ]; do
			if [[ ${yes_arr[@]} =~ ${remove_input} ]]; then
				tmp_inner_bool=1
				echo "You entered 'yes', the custom rule files will be removed at this time..."
				sed -i '/^rule-files:/,/^[^ ]/{/^  - suricata\.rules$/!{/^  - /d;}}' suricata/suricata_mock.yaml
				# debug
				echo "The new rule files: "
				sed -n '/^rule-files:/,/^[^ ]/p' suricata/suricata_mock.yaml
				echo "The rule files have been updated! Continuing setup..."
			elif [[ ${no_arr[@]} =~ ${remove_input} ]]; then
				tmp_inner_bool=1
				echo "You entered 'no', the rule-files will not be updated at this time. Continuing setup..."
			else
				echo "You entered $remove_input, which is not a valid input. Please try again: "
				read -p "You entered 'no', would you like to remove the custom path file? [y/n]: " remove_input
			fi
		done
	else
		echo "You entered $custom_input, which is not a valid input. Please try again: "
		read -p "The default is to only use the suricata.rules, does this match your setup? [y/n]: " custom_input
	fi
done

# Update the Suricata rules before starting

# get the rule path without hte beginning
rule_path=$(grep -m 1 "default-rule-path:" suricata/suricata_mock.yaml | awk '{print $2}')
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
echo "1: Intrusion Detection System (IDS) - Will alert but not block network traffic "
echo "2: Intrusion Prevention System (IPS) - Will alert and/or block network traffic ('advanced' mode)" #idk if we should table the IPS mode... you already have it set up right? why not use something useful
echo "** NOTE: IPS Mode is only recommended for those who have a good understanding of computer networks **"
read -p "Enter your choice (# or abbreviation): " setup_choice

tmp_bool=0

until [ $tmp_bool -eq 1 ]; do
	if [[ ${ids_arr[@]} =~ ${setup_choice} ]]; then
	tmp_bool=1
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
		./suricata/ids-setup-script.sh $pi_ip $usr_interface_selection

	elif [[ ${ips_arr[@]} =~ ${setup_choice} ]]; then
		tmp_bool=1
		echo -e "\nYou have chosen to setup Intrustion Prevention System (IPS)."
		echo "Starting IPS configuraiton..."
		./suricata/ips-setup-script.sh
	else
		echo -e "\nYou entered $setup_choice, which is not a valid answer. Please try again: "
		echo -e "\nWhat configuration type would you like to install?:"
	echo "1: Intrusion Detection System (IDS) - Will alert but not block network traffic "
	echo "2: Intrusion Prevention System (IPS) - Will alert and/or block network traffic ('advanced' mode)" #idk if we should table the IPS mode... y>
	echo "** NOTE: IPS Mode is only recommended for those who have a good understanding of computer networks **"
	read -p "Enter your choice (# or abbreviation): " setup_choice
	fi
done
