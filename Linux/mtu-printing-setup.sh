#!/bin/bash
# 2017-08-02 -- zrjones@mtu.edu
# 2018-05-24 -- joshuaha@mtu.edu Updated Script
# Adds papercut and printers to the system using cups and lpadmin

# Define location for papercut install
location="${HOME}/printing"


# ensure all commands needed for this script are present on the system
# note - this list will need kept up-to-date manually
echo -e "Initializing...\n"
for check_cmd in awk chmod cupsd head java /usr/sbin/lpadmin /usr/bin/lpstat mkdir tar
do
    if ! command -v "${check_cmd}" > '/dev/null' 2>&1
    then
        echo -e "ERROR - Necessary utility not found: ${check_cmd}\n"
        if [[ ${check_cmd} == "/usr/sbin/lpadmin" || ${check_cmd} == "/usr/sbin/lpstat" ]]
        then
                echo -e "lpadmin and lpstat require cups and cups daemon to be running\n"
        fi
        exit 1
    fi
done

# Gather system Java information
jv=$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}')
jvmain=${jv::-4}
jvsub=${jv:6}

if [ "${jvmain}" != "1.8.0" ]
then
        echo -e "Java Main Version: ${jvmain} : Warning"
        echo "Warning: Java Version needs to be 1.8.0 for papercut"
        echo "Continuing..."
else
        echo -e "Java Main Version: ${jvmain} : OK\n"
fi

if [ "$jvsub" -lt "181" ]
then
        echo -e "Java Sub Version : ${jvsub}\t : Caution"
	echo -e "Our testing requried at least 1.8.0.181"
else
	echo -e "Java Sub Version : ${jvsub}\t : OK\n"
fi
echo "Installing..."

# Use, or create, the location path on the system
mkdir --parent "${location}"

# Place download into directory
echo -e "Extracting papercut and print drivers\n"
cp -r "${PWD}/papercut" "${location}"
cp -r "${PWD}/drivers" "${location}"

# Ensure permissions in location
echo "Setting the folder permissions for \"${location}\" as '755'"
chmod -R 755 "${location}"
echo -e "\n####\nThe papercut client is located at ${location}/papercut/pc-client-linux.sh\n####\n"

echo -e "Adding printers, admin privileges required\n"

# Add printers to the system
echo "Enabling cups service"
sudo systemctl enable cups
echo "Starting cups service"
sudo systemctl start cups
echo "Adding husky-bw to cups"
sudo /usr/sbin/lpadmin -p husky-bw -E -v lpd://print.mtu.edu/husky-bw -P "${location}/drivers/husky-bw.ppd"
echo "Adding husky-color to cups"
sudo /usr/sbin/lpadmin -p husky-color -E -v lpd://print.mtu.edu/husky-color -P "${location}/drivers/husky-color.ppd"

echo "Use the shell script located at: ${location}/papercut/pc-client-linux.sh"

exit 0
