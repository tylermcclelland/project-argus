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
read -p "Are you wanting to stay with this rule path or switch to custom rules? [stay/switch]: " rule_choice

tmp_bool=0
until [ $tmp_bool -eq 1 ]; do
	if [[ $rule_choice == "stay" ]]; then
		tmp_bool=1
		echo -e "You selected to stay on this rule path, continuing without update...\n"
	elif [[ $rule_choice == "switch" ]]; then
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
	fi
done

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
