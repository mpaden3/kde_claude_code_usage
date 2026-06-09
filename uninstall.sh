#!/usr/bin/env bash
# Remove the plasmoid completely. Safe to run even if it isn't installed.
set -euo pipefail

ID="org.marko.claudeusage"

kpackagetool6 --type Plasma/Applet --remove "$ID" 2>/dev/null \
    && echo "Removed $ID." \
    || echo "$ID was not installed (nothing to remove)."

echo "All widget files lived only in ~/.local/share/plasma/plasmoids/$ID/ — now gone."
echo "Delete this project folder to finish cleanup."
