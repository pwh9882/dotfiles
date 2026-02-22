#!/bin/bash
# Starship config overrides for woopc (WSL2)
# Applied by .config/init.sh after copying base starship.toml
CONFIG="$1"

# Increase scan timeout for WSL Windows filesystem (/mnt/c/)
sed -i 's/scan_timeout = 30/scan_timeout = 200/' "$CONFIG"

# Linux-style prompt: green user + orange host (Ubuntu vibes)
sed -i 's/style_user = "bold mauve"/style_user = "bold green"/' "$CONFIG"
sed -i '/^\[hostname\]/,/^\[/ s/style = "bold yellow"/style = "bold peach"/' "$CONFIG"
