# Dynamic DNS client that works with GoDaddy and no-ip.com
# Setup wizard will store a configuration file (settings.cfg) with dns to update
#
# Usage: ./jj-ddns-client.windows.ps1 -h

param (
  [switch] $u,
  [switch] $w,
  [switch] $s,
  [switch] $h,
  [switch] $i,
  [switch] $force = $false
)

#region Global variables
$serviceName = "jj-ddns-client.windows"
$userAgent = "jj-ddns-client.windows/v1.2 planetxpres@msn.com"
$ipModes = @("public", "private")
$providers = @("godaddy", "no-ip.com", "google")

# Paths
$invocation = (Get-Variable MyInvocation).Value
$configFile = "$(Split-Path $invocation.MyCommand.Path)\settings.cfg"
$scriptPath = $invocation.MyCommand.Source
$logFile = "$(Split-Path $invocation.MyCommand.Path)\dns.log"
#endregion

function updateDns {
  $settings = loadSettings
  if (isDisabled) {
    throw "Client status is disabled, Run script with -w flag to run wizard"
    return
  }

  if (isSnoozed) {
    log "Client is snoozed to be run on $($settings.snoozeUntil)"
    return
  }

  if ($settings.provider -eq "godaddy") {
    updateDnsGoDaddy
  }
  elseif ($settings.provider -eq "no-ip.com") {
    updateDnsNoIp
  }
  elseif ($settings.provider -eq "google") {
    updateDnsGoogle
  }
  else {
    throw "$($settings.provider) is not a valid value for dns provider. Run script with -w flag to run wizard"
  }
}

function updateDnsGoDaddy {
  log "[$([DateTime]::Now)] Checking godaddy dns..." -clear
  $settings = loadSettings   

  $uri = "https://api.godaddy.com/v1/domains/$($settings.domain)/records/A/$($settings.name)"
  $headers = @{}
  $headers.Add("Authorization", "sso-key $($settings.key):$($settings.secret)")
  $result = Invoke-RestMethod -Method GET -Headers $headers -Uri $uri -UserAgent $userAgent
    
  $dnsIp = $result.data
  $currentIp = getIp
    
  if ($dnsIp -ne $currentIp) {
    log "Updating $($settings.domain) dns record with $currentIp, old ip $dnsIp"
    $request = @(
      @{
          data = $currentIp;
          ttl  = 600;
      }
    );

    $json = ConvertTo-Json $request;
    try {
      $updateResult = Invoke-RestMethod -Method PUT -Headers $headers -Uri $uri -Body $json -ContentType "application/json" -UserAgent $userAgent
      $updateResult | Out-File -FilePath $logFile -Append
      $updateResult
    }
    catch {
      "Error $($_.Exception.Response.StatusCode): $($_.Exception.Response.StatusDescription)" | Out-File -FilePath $logFile -Append
      throw $_.Exception
    }
  }
  else {
    "No need to update IP"
  }

  "Finished check $dnsIp and $currentIp" | Out-File -FilePath $logFile -Append
}

function updateDnsNoIp {
  # https://www.noip.com/integrate
  log "[$([DateTime]::Now)] Checking no-ip dns..." -clear
  $settings = loadSettings

  $currentIp = getIp
  $dnsIp = [System.Net.Dns]::GetHostAddresses($settings.domain).IPAddressToString
      
  if ($dnsIp -ne $currentIp) {
    log "Updating $($settings.domain) dns record with $currentIp, old ip $dnsIp"

    $uri = "http://$($settings.key):$($settings.secret)@dynupdate.no-ip.com/nic/update?hostname=$($settings.domain)&myip=$currentIp"
    $result = Invoke-RestMethod -Method GET -Uri $uri -UserAgent $userAgent

    $result | Out-File -FilePath $logFile -Append
    if ($result.StartsWith("good")) {
      log "no-ip.com succeeded updating ip ($result)"
    }
    elseif ($result.StartsWith("nochg")) {
      log "no-ip.com ip update was not needed ($result)"
    }
    elseif ($result.StartsWith("911")) {
      log "no-ip.com is down, snoozing client during 30 minutes ($result)"
      snoozeUntil [DateTime]::Now.AddMinutes(30)
    }
    elseif (
      $result.StartsWith("nohost") -or 
      $result.StartsWith("badauth") -or 
      $result.StartsWith("badagent") -or 
      $result.StartsWith("abuse") -or
      $result.StartsWith("!donator")
    ) {
      log "no-ip.com has given an error: $result, wizard has to be run again."
      disableClient
    }
  }
  else {
      "No need to update IP"
  }

  log "Finished check $dnsIp and $currentIp"
}


function updateDnsGoogle {
  log "[$([DateTime]::Now)] Updating $($settings.domain) dns record with $currentIp, old ip $dnsIp"
  $settings = loadSettings
  $currentIp = getIp
  
  $uri = "https://$($settings.key):$($settings.secret)@domains.google.com/nic/update?hostname=$($settings.domain)&myip=$currentIp"
  $result = Invoke-RestMethod -Method GET -Uri $uri -UserAgent $userAgent
  log $result

  log "Finished updating domain"
}

function getIp {
  if ((loadSettings).ipmode -eq "public") {
    $webClient = New-Object System.Net.WebClient
    $ip = $webClient.DownloadString('http://ipinfo.io/ip')
  }
  else {
    $ip = (Test-Connection -ComputerName (hostname) -Count 1  | Select-Object -ExpandProperty IPV4Address).IPAddressToString
  }
  $ip.Trim()
}

#region Setup
function install {
  if (!(checkRequiredPrivileges)) {
    throw "Please run this script with admin priviliges"
  }
  uninstall
  configWizard
  addCron

  "Executing client with configuration..."
  updateDns
}

function uninstall {
  if (Test-Path $configFile) {
    Remove-Item -Path $configFile
    "Config removed"
  }

  Unregister-ScheduledTask -TaskName $serviceName -Confirm:$false -ErrorAction SilentlyContinue
}

function confirmUninstall {
  if (!(checkRequiredPrivileges)) {
    throw "Please run this script with admin priviliges"
  }

  if (!($force)) {
    $confirm = Read-Host -Prompt "Do you want to stop updating configured dns (y/n)?"
    if ($confirm -ne "y" ) {
        "Uninstallation cancelled"
        return
    }
  }

  uninstall
}

function helpDialog {
  "script to update a dns address. Options:
	[without arguments]: Update dns with current ip. If no config is found, installation wizard is launched.
	[-w]: Installation wizard
	[-u]: Uninstallation of configured account and execution of script
	[-s]: Show current settings
	[-h]: Show this help dialog"
}

function currentSettingsDialog {
  $settings = loadSettings

  "provider: $($settings.provider)"
  "ipmode: $($settings.ipmode)"
  "domain: $($settings.domain)"
  if (![string]::IsNullOrWhiteSpace($settings.name)) {
    "subdomain: $($settings.name)"
  }
  if (isDisabled) {
    "CLIENT DISABLED STATUS, rerun wizard with -w flag"
  }
  if (![string]::IsNullOrWhiteSpace($settings.snoozeUntil)) {
    "snoozeUntil: $($settings.snoozeUntil)"
  }    
}

function configWizard {
  "Installation wizard"

  $settings = @{}
  $settings.status = "enabled"
  $settings.snoozeUntil = $null
  $settings.provider = promptOptions -options $providers -prompt "Choose dns provider"
  $settings.provider
  $settings.ipKind = promptOptions -options $ipModes -prompt "Choose ip address kind"

  $settings.domain = Read-Host -Prompt "Domain to update"
  if ($settings.provider -eq "godaddy") {
    $settings.name = Read-Host -Prompt "Subdomain name"
    $settings.key = Read-Host -Prompt "GoDaddy developer key (https://developer.godaddy.com/getstarted)"
    $settings.secret = Read-Host -Prompt "GoDaddy developer secret"
  }
  else {
    $settings.key = Read-Host -Prompt "$($settings.provider) user"
    $settings.secret = Read-Host -Prompt "$($settings.provider) password"
  }

  saveSettings $settings
}

function saveSettings($settings) {
  "domain=$($settings.domain)" > $configFile
  "name=$($settings.name)" >> $configFile
  "ipmode=$($settings.ipKind)" >> $configFile
  "provider=$($settings.provider)" >> $configFile
  "key=$($settings.key)" >> $configFile
  "secret=$($settings.secret)" >> $configFile
  "status=$($settings.status)" >> $configFile
  "snoozeUntil=$($settings.snoozeUntil)" >> $configFile
}

function loadSettings {
  if (-not (Test-Path $configFile)) {
    throw [System.IO.FileNotFoundException] "$configFile not found."
  }

  Get-Content $configFile | foreach-object -begin {$settings = @{}} -process { $k = [regex]::split($_, '='); if (($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $settings.Add($k[0], $k[1]) } }
  $settings
}

function addCron {
  "installing service $serviceName ($scriptPath)"
  
  $repeat = (New-TimeSpan -Minutes 15)
  $trigger = New-JobTrigger -Once -At (Get-Date).Date -RepeatIndefinitely -RepetitionInterval $repeat
  $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -File `"$scriptPath`""
  $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd
  $principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Limited

  $task = Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $serviceName -Settings $taskSettings -Description "Dynamic DNS Client" -Principal $principal

  "Installed ddns client to on between 15 min. intervals."
}

function disableClient {
  $settings = loadSettings
  $settings.status = "disabled"
  saveSettings $settings
}

function isDisabled {
  $settings = loadSettings
  $settings.status -eq "disabled"
}

function snoozeUntil([DateTime]$dateTime) {
  $settings = loadSettings
  $settings.snoozeUntil = $dateTime.ToString("s")
  saveSettings $settings
}

function isSnoozed() {
  $settings = loadSettings
  if ([string]::IsNullOrWhiteSpace($settings.snoozeUntil)) {
    return $false
  }

  return (Get-Date -date $settings.snoozeUntil) -gt [DateTime]::Now
}
#endregion

#region Helper functions
function promptOptions($options, $prompt) {
  $opts = $options | ForEach-Object { "$($options.IndexOf($_)+1)) $($_)`r`n" }
  $promptOpts = "$($prompt):`r`n $opts"
  $option = Read-Host -Prompt $promptOpts

  while (!(isNumeric $option) -or $option -gt $options.Length -or $option -le 0) {
    $option = Read-Host -Prompt "You must choose a valid option. Try again.`r`n$promptOpts"
  }
  return $options[$option -1]
}

function checkRequiredPrivileges {
  ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") 
}

function isNumeric ($value) {
  return $value -match "^[\d\.]+$"
}

function log($message, [switch]$clear) {
  if ($clear) {
    "" | Out-File -FilePath $logFile -NoNewline
  }
  $message | Out-File -FilePath $logFile -Append
  Write-Host $message -Debug
}
#endregion

#region Main
# Without params, update dns
if (-not (Test-Path $configFile)) {
  install
}
elseif ($PSBoundParameters.Count -eq 0) {
  updateDns
  return
}

# Run switches
if ($w) {
  install
}
elseif ($u) {
  confirmUninstall
}
elseif ($s) {
  currentSettingsDialog
}
elseif ($i) {
  getIp
}
elseif ($h) {
  helpDialog
}
else {
  "Invalid option: $($args[0])"
}
#endregion