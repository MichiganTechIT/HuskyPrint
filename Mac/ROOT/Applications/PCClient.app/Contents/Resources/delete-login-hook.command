#!/bin/sh

#
# Remove the currently installed login hook.
#

echo
echo
echo "Removing the login hook. Admin rights are required."
echo "Enter your system password if requested..."

sudo sh -c "(
    defaults delete com.apple.loginwindow LoginHook
    )"

echo "Login hook removed."
    
