# jj-ddns-client
Llightweight no-ip dns updater linux bash script which updates hourly public/private ip automatically

## Installation on linux
Simply, create a folder of your preference and run

`mkdir ddns && cd ddns && wget https://raw.githubusercontent.com/joanjane/jj-ddns-client/master/ddns.sh && sudo chmod +x ./ddns.sh  && ./ddns.sh`

The installation will download the script `ddns.sh` in the folder which you run the command and start a wizard.

## Uninstallation
If you wish to remove the scheduled execution of this script, run on its folder: `ddns.sh -u` 

## Help
You can see help of utility with this command: `ddns.sh -h` 


### Some notes
I've developed this utility for myself but I've found that could be interesting to share for people interested developing minimalistic bash scripts or maintaining no-ip dynamic dns updated. You can find an official no-ip client which can be better than this simple script, you can check it out [here](http://www.noip.com/support/knowledgebase/installing-the-linux-dynamic-update-client/)
