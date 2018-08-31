#!/bin/zsh

#
# (c) Copyright 1999-2013 PaperCut Software International Pty Ltd
#
# A simple shell script set the PCClient.app package as a login item.
#
source "${0:h}"/.common
validateMacOSVer "${0:h}"

#
# Make sure our current working dir is set to the location of this script
#
if [ -d /Applications/PCClient.app ]; then
	cd /Applications/PCClient.app/Contents/Resources
else
	cd "${0:h}"
fi

app_dir=`(cd ../..; pwd)`
resources_dir=`pwd`
hook_script="${resources_dir}/login-hook-start"


if [ -z "${PC_HOOK_SCRIPT}" ] ; then
    # assume no quit mode.
    noquit=1
    echo
    echo "Prevent user from quitting the client? [YES or no] "
    read reply leftover
    case $reply in
        [yY] | [yY][eE][sS])
            noquit=1
            ;;
        [nN] | [nN][oO])
            noquit=
            ;;
    esac

    if [ ! -z "${noquit}" ]; then
        hook_script="${resources_dir}/login-hook-start"
    else
        hook_script="${resources_dir}/login-hook-start-no-restart"
    fi
else 
    hook_script=$PC_HOOK_SCRIPT
fi

echo
echo
echo "Installing login hook. Admin rights are required."
echo "Enter your system password if requested..."

sudo sh -c "(
    #
    # Setup permissions so all users have access
    #
    find \"${app_dir}\" -exec chown root:admin {} \; 
    find \"${app_dir}\" -exec chmod 775 {} \; 
    #
    # Set hook script via defaults program
    #
    defaults write com.apple.loginwindow LoginHook \"${hook_script}\"
    )"

echo "Installed."
