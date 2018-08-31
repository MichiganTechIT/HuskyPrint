#!/bin/zsh

#
# (c) Copyright 1999-2013 PaperCut Software International Pty Ltd
#
# A simple shell script to set up Java and launch the client software
# on a Mac system.  
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

#
# Run the program
#

export PC_CLIENT_ARGS="$*"
./../MacOS/JavaAppLauncher