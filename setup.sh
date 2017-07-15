#!/bin/bash
#
# This version uses September 2016 rpi jessie image, please use this image
#

if [ "$EUID" -ne 0 ]
	then echo "Must be root"
	exit
fi

if [[ $# -lt 1 ]]; 
	then echo "You need to pass a password!"
	echo "Usage:"
	echo "sudo $0 yourChosenPassword [apName]"
	exit
fi

APPASS="$1"
APSSID="ElyirHub.AP"
ADAPTER="wlan0"

if [[ $# -eq 2 ]]; then
	APSSID=$2
fi

sudo bash create-ap.sh $APPASS $APSSID
sudo bash passthrough.sh $ADAPTER