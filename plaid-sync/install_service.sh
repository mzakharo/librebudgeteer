#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

sudo cp plaid@.* /etc/systemd/system/
sudo systemctl daemon-reload 
sudo systemctl enable plaid@$USER.service
sudo systemctl enable plaid@$USER.timer
sudo systemctl start  plaid@$USER.timer
sudo systemctl status plaid@$USER.timer 
sudo systemctl status plaid@$USER.service 
