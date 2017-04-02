#!/bin/bash

######################## ddns.sh ########################
# Author: Joan Jané.                                    #
# Description: Script to update no-ip dynamic dns.      #
# Installation: sudo chmod +x ./ddns.sh && ./ddns.sh    #
# Usage: ./ddns.sh -h.                                  #
#########################################################

#### Constants ####
readonly configFile="./settings.cfg"
readonly scriptName="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
#### Constants ####

#### Installation ####
function addCron {
	crontab -l | { cat; echo "0 * * * * $(pwd)/$scriptName"; } | crontab -
}

function configWizard {
	echo "Installation wizard"
	echo "1) no-ip username:"
	read username
	echo "jjUsername=$username" > $configFile
	echo "2) no-ip password:"
	read -s password
	echo "jjPassword=$(echo $password | base64)" >> $configFile
	echo "3) no-ip dynamic dns host to update:"
	read host
	echo "jjHost=$host" >> $configFile
	
	wizardIpKind
	
	echo "Installed ddns client to run each hour."
}

function wizardIpKind {
	echo "Choose ip address kind:
	1) public (default)
	2) private (ex: 192.168.1.10)"
	read ipKind
	
	if [ ! -z "$ipKind" ] && [ $ipKind == "1" ]; then
		echo "jjIpMode=public" >> $configFile
	else if [ ! -z "$ipKind" ] && [ $ipKind == "2" ]; then
		echo "jjIpMode=private" >> $configFile
	else
		echo "You must choose option 1 or 2. Try again."
		wizardIpKind
	fi
	fi
}


function install {
	uninstall
	addCron
	configWizard
	
	echo "Executing client with configuration..."
	updateDns
}
#### Installation ####

#### Uninstallation ####
function uninstall {
	#remove script entry on crontab
	crontab -l | sed "/$scriptName/d" | crontab -
	if [ -f $configFile ]; then
		rm $configFile
	fi
}

function confirmUninstall {
	echo "Do you want to stop updating configured dns (y/n)?" >&2
	read confirm
	if [ $confirm != "y" ]
	then
		echo "Uninstallation cancelled"
		exit 0
	fi
	
	uninstall
}
#### Uninstallation ####

#### DDNS Update ####
function loadSettings {
	if [ ! -f $configFile ]; then
		echo "Config not found, run ./$scriptName to start wizard again"
		exit 1
	fi
	
	# source: http://wiki.bash-hackers.org/howto/conffile
	configFileSecured=$configFile

	# check if the file contains something we don't want
	if egrep -q -v '^#|^[^ ]*=[^;]*' "$configFile"; then
		# filter the original to a new file
		configFileSecured='/tmp/ddns.cfg'
		egrep '^#|^[^ ]*=[^;&]*'  "$configFile" > $configFileSecured
	fi

	source "$configFileSecured"
}

function getIp {
	loadSettings
	if [ $jjIpMode == "public" ]; then
		echo $(curl ipinfo.io/ip -s)
	else
		ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'
	fi
}

function updateDns {
	if [ ! -f $configFile ]; then
		echo "Config not found, running installation wizard"
		install
		exit 0
	fi
	loadSettings
	
	# client user agent
	readonly appVersion="v1.0"
	readonly appName="jj-noip-client"
	readonly appEmail="planetxpres@msn.com"
	readonly userAgent="$appName/$appVersion $appEmail"

	# get current ip
	ip=$(getIp)
	
	echo "Updating dns $jjHost with ip $ip"
	
	# update dns
	password=$(echo $jjPassword | base64 --decode)
	req="http://$jjUsername:$password@dynupdate.no-ip.com/nic/update?hostname=$jjHost&myip=$ip"
	curl $req -A '$userAgent' -s
	echo "Updated dns"
}

#### DDNS Update ####

#### Script dialog ####

function helpDialog {
	echo "$scriptName script to update no-ip dns options:
	[without arguments]: Update dns with current ip. If no config is found, installation wizard is launched.
	[-w]: Installation wizard, can be run to update the configured no-ip account
	[-u]: Uninstallation of configured account and execution of script
	[-s]: Show settings of configured no-ip account
	[-h]: Show this help dialog"
}

function currentSettingsDialog {
	loadSettings
	echo "username: $jjUsername"
	echo "host: $jjHost"
}

# without params, update dns
if [ "$#" == "0" ]; then
	updateDns
	exit 0
fi

while getopts ":u :w :s :h :i" opt; do
	case $opt in
		w)
			install
			;;
		u)
			confirmUninstall
			;;
		s)
			currentSettingsDialog
			;;
		i)
			getIp
			;;
		h)
			helpDialog
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			helpDialog
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			helpDialog
			exit 1
			;;
	esac
done
