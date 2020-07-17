#!/bin/bash
# Dynamic DNS client that works with GoDaddy and no-ip.com
# Setup wizard will store a configuration file (settings.cfg) with dns to update
#
# Usage: ./jj-ddns-client.linux.sh -h

#region Global variables
readonly serviceName="jj-ddns-client.linux"
readonly userAgent="jj-ddns-client.linux/v1.2 planetxpres@msn.com"
readonly ipModes=("public" "private")
readonly providers=("godaddy" "no-ip.com", "google")

readonly configFile="$(dirname $0)/settings.cfg"
readonly logFile="$(dirname $0)/dns.log"
readonly scriptName="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
newLine=`echo $'\n.'`
newLine=${newLine%.}
#endregion

#region functions
function checkDisabled {
  loadSettings
  if [ $status == "disabled" ]; then
    echo "Client status is disabled, Run script with -w flag to run wizard"
    exit 1
  fi
}

function checkSnoozed {
  loadSettings
  now=$(date '+%Y-%m-%dT%H:%M:%S')
  if [ ! -z "$snoozeUntil" ] && [ "$snoozeUntil" \< $now ]
  then
    echo "Client is snoozed to be run on $snoozeUntil"
    exit 0
  fi
}

## Pass number of minutes as argument
function snoozeUntil {
  $minutes = $1
  loadSettings
  snoozeUntil=$(date --date '$minutes minutes' '+%Y-%m-%dT%H:%M:%S')
  saveSettings
  echo "Client is snoozed to be run on $snoozeUntil"
  exit 0
}

## Pass message and flag if should append log (default true)
function log {
  message=$1
  append=${2:-true}
  if [ $append ]; then
    echo $message >> $logFile
  else
  echo $message > $logFile
  fi
  echo $message
}

## Pass message and array of options to prompt, returns picked option index starting from 1
function promptOptions {
  options=()
  for ((i=2;i<=$#;i++));
  do
    options+=("${!i}")
  done

  prompt=$"${1} $newLine"
  count=${#options[@]}
  i=1
  for opt in ${options[@]}; do
    prompt="$prompt$i) $opt$newLine"
    i=$(($i+1))
  done

  read -p $"$prompt" option
  while [[ $option -lt 1 || $option -gt $count ]]; do
    echo "$option is not a valid option. Try again."
    read -p $"$prompt" option
  done

  echo ${options[$option-1]}
}
#endregion


function updateDns {
  loadSettings
  checkDisabled
  checkSnoozed

  if [ "$provider" == "godaddy" ]; then
    updateDnsGoDaddy
  elif [ "$provider" == "no-ip.com" ]; then
    updateDnsNoIp
  elif [ "$provider" == "google" ]; then
    updateDnsGoogle
  else
    echo "$provider is not a valid value for dns provider. Run script with -w flag to run wizard"
    exit 1
  fi
}

function updateDnsGoDaddy {
  loadSettings

  headers="Authorization: sso-key $key:$secret"

  result=$(curl -s -X GET -H "$headers" \
  "https://api.godaddy.com/v1/domains/$domain/records/A/$name")

  dnsIp=$(echo $result | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")

  currentIp=$(getIp)

  log "[$(date +%Y-%m-%dT%H:%M:%S)] Checking dns..." false

  if [ "$dnsIp" != "$currentIp" ]; then
    log "Updating $domain dns record with $currentIp, old ip $dnsIp"
    request='[{"data":"'$currentIp'","ttl":600}]'
    nresult=$(curl -i -s -X PUT \
      -H "$headers" \
      -H "Content-Type: application/json" \
      -d $request "https://api.godaddy.com/v1/domains/$domain/records/A/$name")
    log $nresult
  fi

  log "Finished check $dnsIp and $currentIp"
}

function updateDnsNoIp {
  loadSettings
  log "[$(date +%Y-%m-%dT%H:%M:%S)] Checking dns..." false
  
  dnsIp=$(host $domain | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
  currentIp=$(getIp)

  if [ "$dnsIp" != "$currentIp" ]; then
    log "Updating $domain dns record with $currentIp, old ip $dnsIp"

    headers="User-Agent: $userAgent"
    uri = "http://$key:$secret@dynupdate.no-ip.com/nic/update?hostname=$domain&myip=$currentIp"
    result=$(curl -s -X GET -H "$headers" "$uri")
    log $result
  fi
  log "Finished"
}

function updateDnsGoogle {
  loadSettings
  
  log "Updating $domain dns record with $currentIp" false
  result=$(curl -i -s -X GET \
    -H "Content-Type: application/json" \
    -d $request "https://$key:$secret@domains.google.com/nic/update?hostname=$domain&myip=$currentIp")
  log $result
  log "Finished"
}

function loadSettings {
  if [ ! -f $configFile ]; then
    log "Config not found, add to start wizard again"
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

  if [ $ipmode == "public" ]; then
    echo $(curl ipinfo.io/ip -s)
  else
    ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'
  fi
}

#region Setup
function addCron {
  crontab -l | { cat; echo "*/15 * * * * $(pwd)/$scriptName"; } | crontab -
  echo "Installed ddns client to on between 15 min. intervals."
}

function install {
  uninstall
  configWizard
  addCron

  log "Executing client with configuration..."
  updateDns
}

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

function helpDialog {
  echo "$scriptName script to update godaddy dns. Options:
  [without arguments]: Update dns with current ip. If no config is found, installation wizard is launched.
  [-w]: Installation wizard
  [-u]: Uninstallation of configured account and execution of script
  [-s]: Show current settings
  [-h]: Show this help dialog"
}

function currentSettingsDialog {
  loadSettings
  checkDisabled

  echo "provider: $provider"
  echo "ipmode: $ipmode"
  echo "domain: $domain"
  if [ $name ]; then
    echo "subdomain=$name"
  fi
  echo "snoozeUntil: $snoozeUntil"
}

function saveSettings {
  echo "domain=$domain" > $configFile
  echo "name=$name" >> $configFile
  echo "ipmode=$ipmode" >> $configFile
  echo "provider=$provider" >> $configFile
  echo "key=$key" >> $configFile
  echo "secret=$secret" >> $configFile
  echo "status=$status" >> $configFile
  echo "snoozeUntil=$snoozeUntil" >> $configFile
}

function configWizard {
  echo "Installation wizard"

  provider=$(promptOptions "Choose dns provider:" "${providers[@]}")  
  ipmode=$(promptOptions "Choose ip address kind:" "${ipModes[@]}")
  
  read -p "Domain to update:$newLine" domain

  if [ "$provider" == "godaddy" ]; then
    read -p "Subdomain name:$newLine" name
    read -p "GoDaddy developer key (https://developer.godaddy.com/getstarted):$newLine" key
    read -p "GoDaddy developer secret:$newLine" secret
  else
    read -p "$provider user:$newLine" key
    read -p "$provider password:$newLine" secret
  fi
  status="enabled"

  saveSettings
}
#endregion

#region Main
# without params, update dns
if [ ! -f $configFile ]; then
  install
elif [ "$#" == "0" ]; then
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
#endregion
