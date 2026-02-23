#!/bin/bash
# Starship config overrides for Linux (all machines)
# Applied by .config/init.sh after copying base starship.toml
CONFIG="$1"

# Linux-style prompt: green user + orange host (distinguish from macOS)
sed -i 's/style_user = "bold mauve"/style_user = "bold green"/' "$CONFIG"
sed -i '/^\[hostname\]/,/^\[/ s/style = "bold yellow"/style = "bold peach"/' "$CONFIG"
