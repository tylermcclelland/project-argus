#!/bin/bash

# This script will aid a user in setting up Suricata to run in IDS mode. 
#
# I realize this implementation isn't the cleanest. Demo is soon and this route (storing a .yaml w/ ids friendly optinos and just overwriting 
# the existing suricata.yaml which may have IDS configurations enabled) seemed wesy to get working. Time permitting, I would like to think of a more
# "elegant" solution.


# For testing purposes
echo "IDS setup script running!"

# passing already procured ip and interface selection to this script
pi_ip=$1
usr_interface_selection=$2

# copying a known "out of the box" .yaml (which has no IPS specific config options added to; effectively already in IDS mode after running setup)
echo "If you have any special configurations in your current suricata.yaml that you want to save? [yes/no]"
echo "NOTE: you're current suricata configuration (/etc/suricata/suricata.yaml) will be overwritten if you say no"
read usr_choice
tmp_bool=0
until [ $tmp_bool -eq 1 ]; do
    if [[ $usr_choice == "yes" ]]; then
        echo "will add implementation to back up your current yaml for later use"
        echo -e "Please provide the path of the .yaml you want to save: "
        echo -e "Enter as \"/this/is/my/path/configFile.yaml\" where configFile.yaml is the file you want to save in this case: "
        read usr_saved_yaml_path
        read -p "where do you want to save it too? ex: /I/wanna/save/it/here" usr_path_to_save_yaml
        #long var names because I keep getting confused TODO: clean up 
        sudo touch $usr_path_to_save_yaml/your_saved_yaml.yaml
        if [ $tmp_exit_code -eq 0]; then
            echo -e "Temp file made..."
        else
            echo "Temp file not made! be sure you're providing the right path to save to... \n"
        fi
        sudo cp $usr_saved_yaml_path $usr_path_to_save_yaml/your_saved_yaml.yaml
        tmp_exit_code=$?
        if [ $tmp_exit_code -eq 0]; then
            echo -e "your file was stored succesfully to $usr_path_to_save_yaml! \n"
        else
            echo "Your file wasn't saved... Make sure you're giving the right paths/filenames"
        fi

    elif [[ $usr_choice == "no" ]]; then
        echo "Okay, replacing your suricata.yaml with an IDS friendly suricata.yaml"
        #sudo cp suricata/other-files/temp-ids.yaml /etc/suricata/suricata.yaml //to be used in final script
        sudo cp suricata/other-files/temp-ids.yaml suricata_mock.yaml 
        tmp_exit_code=$?
        if [ $tmp_exit_code -eq 0 ]; then
            echo -e "New suricata.yaml succesfully saved to /etc/suricata/suricata.yaml! \n"
        else
            echo -e "suricata.yaml failed to be overwritten... Exit code: $tmp_exit_code \n"
        fi
    else
        echo -e "You entered: $user_choice. This is not a valid choice, you must type \"yes\" or \"no\"."
        echo -e "Trying again... \n"
    fi


done

echo -e "Now that we've have got a fresh IDS friendly .yaml, we need to update it with the right info \n"
echo "starting to update the new .yaml..."


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
	echo "IP address has been updated in suricata.yaml!" #TODO: eventually (not necessary for the demo) we should probably put a check here for a valid IP such that I cant say my IP is "potato"
fi

# Make sure that the rules file is up to date/the correct file path
current_rule_path=$(grep "default-rule-path" suricata_mock.yaml)
echo -e "\nYour default rule path is currently set to: \n$current_rule_path"

read -p "The default rules file is /var/lib/suricata/rules. Does this match your file location? [yes/no]: " rule_input

if [[ $rule_input == "yes" ]]; then
	echo "You entered 'yes', checking that the default-rule-path matches..."
	# update to real file in future :)
	if grep -q "default-rule-path: /var/lib/suricata/rules" suricata_mock.yaml; then
		echo -e "Default rule path matches! Continuing setup...\n"
	else
		def_rule_path="default-rule-path:.*"
		echo "You entered yes, but your default rule path currently set to:"
		echo $def_rule_path
		read -p "Would you like to update to the default? [yes/no]: " update_input
		if [[ $update_input == "yes" ]]; then
			update_rule_path="default-rule-path: /var/lib/suricata/rules"
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
		update_rule_path="default-rule-path: /var/lib/suricata/rules"
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
echo "IDS setup done!"
#sudo cp suricata/other-files/temp-ids.yaml suricata_mock.yaml

#verifying we have the correct interface and HOME_NET setup in the yaml
