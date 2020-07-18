# jj-ddns-client
Lightweight client with minimal dependencies to update dns and dynamic dns from some providers. Written in bash for linux and powershell for windows.

Features:
* Support for Google Domains, GoDaddy, NoIP and ChangeIP (thanks @lioneldaniel for the last one)
* Support for setting public / private ip of a concrete network interface.
* CronJob/Scheduled Task that runs periodically (15min)
* Wizard to setup the configuration.

## Installation on linux
Simply, create a folder of your preference and run:

```bash
mkdir jj-ddns-client && cd jj-ddns-client && wget https://raw.githubusercontent.com/joanjane/jj-ddns-client/master/jj-ddns-client.linux.sh && sudo chmod +x ./jj-ddns-client.linux.sh && ./jj-ddns-client.linux.sh
```

The installation will download the script `jj-ddns-client.linux.sh` and `jj-ddns-client.windows.ps1` in the folder which you run the command and start a wizard. This scripts won't be available on your global path, so be sure to run it on the choosen folder.

## Installation on windows
Simply, create a folder of your preference and run in a powershell console with **admin privileges**:

```bash
(mkdir jj-ddns-client); (cd jj-ddns-client); (wget https://raw.githubusercontent.com/joanjane/jj-ddns-client/master/jj-ddns-client.windows.ps1 -OutFile jj-ddns-client.windows.ps1); (./jj-ddns-client.windows.ps1)
```

The installation will download the script `jj-ddns-client.windows.ps1` in the folder which you run the command and start a wizard.

## Uninstallation
If you wish to remove the scheduled execution of this script, run on its folder: `jj-ddns-client.linux.sh -u` or `jj-ddns-client.windows.ps1 -u`

## Help
You can see help of utility with this command: `jj-ddns-client.linux.sh -h` or `jj-ddns-client.windows.ps1 -h` 

## Warn
This scripts save the configurations in plain text, including the secrets needed to update domains. Beware warned that is not a secure way to store credentials, use it at your own risk.

This tool is not designed to be used on any production environment.

### Some notes
I've developed this utility for myself but I've found that could be interesting to share for people interested developing minimalistic bash scripts or maintaining dynamic dns hosts. 

You can find an official no-ip client which can be better than this simple script, you can check it out [here](http://www.noip.com/support/knowledgebase/installing-the-linux-dynamic-update-client/). To setup no-ip on this tool, the credentials must be the email and password of your account.

On Google Domains, Dynamic DNS hosts are supported. You need to get the credentials (username/password) of the host you want to update.

For GoDaddy, look documentation to generate the needed api keys: https://developer.godaddy.com/getstarted and https://developer.godaddy.com/keys

For ChangeIP, to setup this tool, the credentials must be the email and password of your account.
