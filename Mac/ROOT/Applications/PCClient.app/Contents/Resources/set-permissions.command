#!/bin/zsh

#
# (c) Copyright 1999-2006 PaperCut Software International Pty Ltd
#
# A simple shell script set the .app file permissions to allow access
# to all users.
#

#
# Make sure our current working dir is set to the location of this script
#
if [ -d /Applications/PCClient.app ]; then
	cd /Applications/PCClient.app/Contents/Resources
else
	cd "${0:h}"
fi

app_dir=`(cd ../..; pwd)`

echo
echo
echo "Setting permissions.  Admin rights are required."
echo "Enter your system password if requested..."

sudo sh -c "(
    find \"${app_dir}\" -exec chown root:admin {} \; 
    find \"${app_dir}\" -exec chmod 775 {} \; 
    )"

echo "Complete."
