#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

sudo cp wealthica@.* /etc/systemd/system/
sudo systemctl daemon-reload 
sudo systemctl enable wealthica@$USER.service
sudo systemctl enable wealthica@$USER.timer
sudo systemctl start  wealthica@$USER.timer
sudo systemctl status wealthica@$USER.timer 
sudo systemctl status wealthica@$USER.service 
