# jj-ddns-client
Llightweight client to update dns from no-ip and godaddy in bash for linux and powershell for windows using the current client ip (public or private). After the setup, the script will update the ip periodically (15min).

## Installation on linux
Simply, create a folder of your preference and run:

```bash
mkdir jj-ddns-client && cd jj-ddns-client && wget https://raw.githubusercontent.com/joanjane/jj-ddns-client/master/jj-ddns-client.linux.sh && sudo chmod +x ./jj-ddns-client.linux.sh  && ./jj-ddns-client.linux.sh
```

The installation will download the script `jj-ddns-client.linux.sh` and `jj-ddns-client.windows.ps1` in the folder which you run the command and start a wizard. This scripts won't be available on your global path, so be sure to run it on the choosen folder.

## Installation on windows
Simply, create a folder of your preference and run

```bash
mkdir jj-ddns-client && cd jj-ddns-client && wget https://raw.githubusercontent.com/joanjane/jj-ddns-client/master/jj-ddns-client.windows.ps1 && ./jj-ddns-client.windows.ps1
```

The installation will download the script `jj-ddns-client.windows.ps1` in the folder which you run the command and start a wizard.

## Uninstallation
If you wish to remove the scheduled execution of this script, run on its folder: `jj-ddns-client.linux.sh -u` or `jj-ddns-client.windows.ps1 -u`

## Help
You can see help of utility with this command: `jj-ddns-client.linux.sh -h` or `jj-ddns-client.windows.ps1 -h` 

## Warn
This scripts save the configurations in plain text, including the secrets needed to update domains. Beware warned that is not a secure way to store credentials, use it at your own risk.

### Some notes
I've developed this utility for myself but I've found that could be interesting to share for people interested developing minimalistic bash scripts or maintaining no-ip dynamic dns and godaddy domains updated. 

You can find an official no-ip client which can be better than this simple script, you can check it out [here](http://www.noip.com/support/knowledgebase/installing-the-linux-dynamic-update-client/)

For godaddy, look documentation to generate the needed api keys: https://developer.godaddy.com/getstarted and https://developer.godaddy.com/keys