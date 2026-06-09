#!/usr/bin/env bash
# Install (or upgrade) the Claude Session Usage plasmoid into the user's home.
# No root, no system files — everything lands in ~/.local/share/plasma/plasmoids/.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$DIR/package"
ID="org.marko.claudeusage"

if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -q "$ID"; then
    echo "Upgrading $ID ..."
    kpackagetool6 --type Plasma/Applet --upgrade "$PKG"
else
    echo "Installing $ID ..."
    kpackagetool6 --type Plasma/Applet --install "$PKG"
fi

echo
echo "Installed. Right-click your panel → Add Widgets → search 'Claude Session Usage'."
echo "If it does not show up yet, reload the shell:"
echo "    kquitapp6 plasmashell && (kstart plasmashell >/dev/null 2>&1 &)"
