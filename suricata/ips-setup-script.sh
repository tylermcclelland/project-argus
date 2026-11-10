#!/bin/bash

# This script will allow for users to run Suricata as an IPS.
# This allows for monitoring and sending alerts, similar to IDS,
# but also can enable blocking with custom rules/using the default
# rules included in Suricata.
#
# This is mostly recommended for more advanced or technologically
# familiar users to ensure that nothing is accidentally or
# unintentionally blocked/regulated by non-technical users. More
# information and setup can be found at the ~36 minute mark of this
# video: https://www.youtube.com/watch?v=8Q3Nhyvh-1I

# Confirm that the script has executed
echo "Intrusion Prevention System (IPS) script is now running!"

# check if the NFQUEUE is already enabled in the current Suricata build
echo -e "\nChecking if NFQueue is enabled..."
suricata --build-info | grep "NFQueue"
nfq_enabled=$(suricata --build-info | grep "NFQueue support" | awk '{print $2}')
if [[ nfq_enabled == "no" ]]; then
	# need to look into how to actually install/enable if not auto enabled
	echo "NFQueue is not currently supported on your build."
else
	echo "NFQueue is already supported on your current build!"
fi

echo -e "\nChecking that NFQueue rules are uncommented in suricata.yaml..."
grep -A 8 "nfq:" suricata_mock.yaml

# check mode: accept
if grep -qE '^[[:space:]]*#[[:space:]]*mode:[[:space:]]*accept' suricata_mock.yaml; then
	echo "'mode' currently commented. Updating to uncommented..."
	sed -i.bak 's/^[[:space:]]*#[[:space:]]*mode:/ mode:/' suricata_mock.yaml
	echo "'mode' is no longer commented. Continuing checks..."
else
	echo "'mode' already uncommented. Continuing checks..."
fi

# check repeat-mark: 1
if grep -qE '^[[:space:]]*#[[:space:]]*repeat-mark:[[:space:]]*1' suricata_mock.yaml; then
        echo "'repeat-mark' currently commented. Updating to uncommented..."
        sed -i.bak 's/^[[:space:]]*#[[:space:]]*repeat-mark:/ repeat-mark:/' suricata_mock.yaml
        echo "'repeat-mark' is no longer commented. Continuing checks..."
else
        echo "'repeat-mark' already uncommented. Continuing checks..."
fi

# check repeat-mask: 1
if grep -qE '^[[:space:]]*#[[:space:]]*repeat-mask:[[:space:]]*1' suricata_mock.yaml; then
        echo "'repeat-mask' currently commented. Updating to uncommented..."
        sed -i.bak 's/^[[:space:]]*#[[:space:]]*repeat-mask:/ repeat-mask:/' suricata_mock.yaml
        echo "'repeat-mask' is no longer commented. Continuing checks..."
else
        echo "'repeat-mask' already uncommented. Continuing checks..."
fi

# check route-queue 2
if grep -qE '^[[:space:]]*#[[:space:]]*route-queue:[[:space:]]*2' suricata_mock.yaml; then
        echo "'route-queue' currently commented. Updating to uncommented..."
        sed -i.bak 's/^[[:space:]]*#[[:space:]]*route-queue:/ route-queue:/' suricata_mock.yaml
        echo "'route-queue' is no longer commented. Continuing checks..."
else
        echo "'route-queue' already uncommented. Continuing checks..."
fi

# sanity check print for testing
# grep -A 8 "nfq:" suricata_mock.yaml

# Check they are not wanting to use a custom rule set
current_rule_path=$(grep "default-rule-path" suricata_mock.yaml)
echo -e "\nYour default rule path is currently set to: \n$current_rule_path"
read -p "Are you wanting to stay with this rule path or switch to custom rule path? [stay/switch]: " rule_choice

# get a boolean that = 1 if updates were made so it doesnt update suricata rules every time
updated_suricata_rules=0

tmp_bool=0
until [ $tmp_bool -eq 1 ]; do
	if [[ $rule_choice == "stay" ]]; then
		tmp_bool=1
		echo -e "You selected to stay on this rule path, continuing without update...\n"
	elif [[ $rule_choice == "switch" ]]; then
		def_rule_path="default-rule-path:.*"
		updated_suricata_rules=1
		read -p "You chose to switch to a custom rule path. Please enter the path you would like to use instead: " new_path
		tmp_bool=1
		tmp_inner_bool=0
		until [ $tmp_inner_bool -eq 1 ]; do
			read -p "You entered $new_path, is this the correct path? [yes/no]: " user_input
			if [[ $user_input == "yes" ]]; then
				tmp_inner_bool=1
				update_rule_path="default-rule-path: $new_path"
				sudo sed -i.bak "0,/$def_rule_path/s|$def_rule_path|$update_rule_path|" suricata_mock.yaml
				echo "The rule path has been updated! Restarting Suricata to update rule path..."
				sudo systemctl restart suricata
				echo -e "Suricata has been restarted! Continuing setup...\n"
			else 
				echo "You said it was not the correct path. Please enter again: "
			fi
		done
	else
		echo "You said $rule_choice, which is not a valid choice."
		echo "Please enter 'stay' or 'switch' when trying again..."
		read -p "Are you wanting to stay with this rule path or switch to custom rule path? [stay/switch]: " rule_choice
	fi
done

# Check if user wants to add custom rules for IPS mode
echo "The current rule-files being used at runtime:"
# Print not just the first 2 lines
sed -n '/^rule-files:/,/^[^ ]/p' suricata_mock.yaml

read -p "These are the rule-files currently used at runtime. Would you like to add a custom rule file? [yes/no]: " add_custom

tmp_bool=0
until [ $tmp_bool -eq 1 ]; do
	if [ $add_custom == "yes" ]; then
		updated_suricata_rules=1
		tmp_bool=1
		read -p "You entered 'yes', please enter the file path for your custom rules file: " custom_file_path
		tmp_inner_bool=0
		until [ $tmp_inner_bool -eq 1 ]; do
			echo "You entered the following file path:"
			echo $custom_file_path
			read -p "Is this the correct file path? [yes/no]: " correct_path
			if [ $correct_path == "yes" ]; then
				tmp_inner_bool=1
				echo "You said 'yes', adding to the end of the Suricata rule-files..."
				# update path using awk to append to end
				sudo awk -v rule="$custom_file_path" '{ lines[NR]=$0; if (/^rule-files:/) in_rules=1; else if (in_rules && /^[^ ]/) in_rules=0; else if (in_rules && /^  - /) last=NR } END { for (i=1; i<=NR; i++) { print lines[i]; if (i==last) print "  - " rule } }' suricata_mock.yaml > /tmp/suricata_mock.yaml && sudo cp /tmp/suricata_mock.yaml suricata_mock.yaml
				echo "The rule path has been added! The current rule-files are now:"
				sed -n '/^rule-files:/,/^[^ ]/p' suricata_mock.yaml
			else
				echo "You said 'no', please find the correct file path and enter again..."
				read -p "What is the file path for your custom rules file?: " custom_file_path
			fi
		done
	elif [ $add_custom == "no" ]; then
		tmp_bool=1
		echo -e "You entered 'no', so no custom rule-files will be added at this time. Continuing setup...\n"
	else
		echo -e "You entered '$add_custom', which is not a valid input. Please enter 'yes' or 'no'.\n"
		read -p "These are the rule-files currently used at runtime. Would you like to add a custom rule file? [yes/no]: " add_custom
	fi
done

# only run updates if needed
if [ $updated_suricata_rules -eq 1 ]; then
	echo "The default rule path or a custom file has been added, updating Suricata rules..."
	rule_path=$(grep -m 1 "default-rule-path:" suricata_mock.yaml | awk '{print $2}')
	sudo suricata-update -o $rule_path
	tmp_exit_code=$?
	if [ $tmp_exit_code -gt 0 ]; then
		echo "Suricata has failed to update and test your rules. Exit code: $tmp_exit_code"
	else
		echo -e "Suricata has successfully updated and tested your rules!\n"
	fi
fi

# Setup NFQUEUE rules (just the video defaults for the demo)
echo "Setting up basic NFQUEUE rules..."
sudo iptables -I INPUT -p icmp -j NFQUEUE --queue-num 2
sudo iptables -I OUTPUT -p icmp -j NFQUEUE --queue-num 2
echo "NFQUEUE rules complete! Displaying iptables: "
sudo iptables -vnL

# Tell user how to start and allow them to opt into auto start
echo -e "\nTo start Suricata in IPS mode, type 'sudo suricata -c /etc/suricata/suricata.yaml -q 2'"
read -p "Would you like the script to start IPS mode for you? [yes/no]: " run_ips

tmp_bool=0
until [ $tmp_bool -eq 1 ]; do
	if [ $run_ips == "yes" ]; then
		tmp_bool=1
		echo "You entered 'yes', starting Suricata in IPS mode!"
		sudo suricata -c /etc/suricata/suricata.yaml -q 2
	elif [ $run_ips == "no" ]; then
		tmp_bool=1
		echo "You entered 'no'. Suricata will not begin at this time."
	else
		echo "You entered '$tmp_bool' which is not a valid input. Please try again [yes/no]!"
	fi
done
