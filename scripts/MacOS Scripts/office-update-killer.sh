#!/bin/sh
#set -x

TOOL_NAME="Microsoft Office 365/2019/2016 Reset Update Message Tool"
TOOL_VERSION="1.1"

## Copyright (c) 2018 Microsoft Corp. All rights reserved.
## Scripts are not supported under any Microsoft standard support program or service. The scripts are provided AS IS without warranty of any kind.
## Microsoft disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a 
## particular purpose. The entire risk arising out of the use or performance of the scripts and documentation remains with you. In no event shall
## Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever 
## (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary 
## loss) arising out of the use of or inability to use the sample scripts or documentation, even if Microsoft has been advised of the possibility
## of such damages.
## Feedback: pbowden@microsoft.com

# Constants
WORD2016PATH="/Applications/Microsoft Word.app"
EXCEL2016PATH="/Applications/Microsoft Excel.app"
POWERPOINT2016PATH="/Applications/Microsoft PowerPoint.app"
SCRIPTPATH=$( cd $(dirname $0) ; pwd -P )

# Shows tool usage and parameters
function ShowUsage() {
	echo $TOOL_NAME - $TOOL_VERSION
	echo "Purpose: Resets the 'Office Update' message bar that appears when the installed build is older than 90 days"
	echo "Usage: ResetUpdateMessage [--All] [--ForceClose]"
	echo "Example: ResetUpdateMessage --All"
	echo
	exit 0
}

# Check for application running state
function CheckRunning() {
	OPENAPPS=0
	WORDRUNSTATE=$(CheckLaunchState "$WORD2016PATH")
	if [ "$WORDRUNSTATE" == "1" ]; then
		OPENAPPS=$(($OPENAPPS + 1))
		echo "WARNING: Word must be restarted for the change to take effect."
	fi
	EXCELRUNSTATE=$(CheckLaunchState "$EXCEL2016PATH")
	if [ "$EXCELRUNSTATE" == "1" ]; then
		OPENAPPS=$(($OPENAPPS + 1))
		echo "WARNING: Excel must be restarted for the change to take effect."
	fi
	POWERPOINTRUNSTATE=$(CheckLaunchState "$POWERPOINT2016PATH")
	if [ "$POWERPOINTRUNSTATE" == "1" ]; then
		OPENAPPS=$(($OPENAPPS + 1))
		echo "WARNING: PowerPoint must be restarted for the change to take effect."
	fi
}

# Checks to see if a process is running
function CheckLaunchState() {
	local RUNNING_RESULT=$(ps ax | grep -v grep | grep "$1")
	if [ "${#RUNNING_RESULT}" -gt 0 ]; then
		echo "1"
	else
		echo "0"
	fi
}

# Forcibly terminates a running process
function ForceTerminate() {
	$(ps ax | grep -v grep | grep "$1" | awk '{print $1}' | xargs kill -9 2> /dev/null)
}

# Force quit all Office apps affected by this tool
function ForceQuitApps() {
	ForceTerminate "$WORD2016PATH"
	ForceTerminate "$EXCEL2016PATH"
	ForceTerminate "$POWERPOINT2016PATH"
}

# Checks to see if the user has root-level permissions
function GetSudo() {
	if [ "$EUID" != "0" ]; then
		sudo -p "Enter administrator password: " echo
		if [ $? -eq 0 ] ; then
			echo "0"
		else
			echo "1"
		fi
	fi
}

# Updates the last modification time of the app plist
function TouchPlist() {
	APPCOUNT=0
	ERRORCOUNT=0
	PRIVS=$(GetSudo)
	TOUCHDATE=$(date "+%Y%m%d0001")
	if [ "$PRIVS" == "1" ]; then
		echo "1"
	else
		if [ -e "$WORD2016PATH" ]; then
			APPCOUNT=$(($APPCOUNT + 1))
			sudo /usr/bin/touch -mt $TOUCHDATE "$WORD2016PATH/Contents/Info.plist"
			if [ "$?" == "1" ]; then
				ERRORCOUNT=$(($ERRORCOUNT + 1))
			fi
		fi
		if [ -e "$EXCEL2016PATH" ]; then
			APPCOUNT=$(($APPCOUNT + 1))
			sudo /usr/bin/touch -mt $TOUCHDATE "$EXCEL2016PATH/Contents/Info.plist"
			if [ "$?" == "1" ]; then
				ERRORCOUNT=$(($ERRORCOUNT + 1))
			fi
		fi
		if [ -e "$POWERPOINT2016PATH" ]; then
			APPCOUNT=$(($APPCOUNT + 1))
			sudo /usr/bin/touch -mt $TOUCHDATE "$POWERPOINT2016PATH/Contents/Info.plist"
			if [ "$?" == "1" ]; then
				ERRORCOUNT=$(($ERRORCOUNT + 1))
			fi
		fi
	fi
	if [ $APPCOUNT -gt 0 ]; then
		if [ $ERRORCOUNT -gt 0 ]; then
			echo "1"
		else
			echo "0"
		fi
	else
		echo "2"
	fi
	return	
}

# Evaluate command-line arguments
if [[ $# = 0 ]]; then
	ShowUsage
else
	for KEY in "$@"
	do
	case $KEY in
		--Help|-h|--help)
		ShowUsage
		shift # past argument
		;;
		--All|-a|--all)
		TOUCHNOW=true
		shift # past argument
		;;
		--ForceClose|-f|--forceclose)
		TOUCHNOW=true
		FORCECLOSE=true
		shift # past argument
		;;
		*)
		ShowUsage
		;;
	esac
	shift # past argument or value
	done
fi

## Main
if [ $TOUCHNOW ]; then
	if [ $FORCECLOSE ]; then
		ForceQuitApps
	else
		CheckRunning
	fi
	TOUCHRESULT=$(TouchPlist)
	if [ "$TOUCHRESULT" == "0" ]; then
		echo "The message bar was reset successfully."
	elif [ "$TOUCHRESULT" == "2" ]; then
		echo "WARNING: No Office applications were found."
	else
		echo "ERROR: An error occurred while resetting the message bar."
		exit 1
	fi
fi

exit 0

