#!/bin/bash

# This script will aid a user in setting up Suricata to run in IDS mode. 
#
#
#
#
# For testing purposes
echo "IDS setup script running!"


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
            echo -e "new suricata.yaml succesfully saved to /etc/suricata/suricata.yaml! \n"
        else
            echo -e "suricata.yaml failed to be overwritten... Exit code: $tmp_exit_code \n"
        fi
    else
        echo -e "You entered: $user_choice. This is not a valid choice, you must type \"yes\" or \"no\"."
        echo -e "Trying again... \n"
    fi


done
sudo cp suricata/other-files/temp-ids.yaml suricata_mock.yaml

#verifying we have the correct interface and HOME_NET setup in the yaml
