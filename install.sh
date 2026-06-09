#!/usr/bin/env bash
# Install (or upgrade) the Claude Session Usage plasmoid into the user's home.
# No root, no system files — everything lands in ~/.local/share/plasma/plasmoids/.
#
# Builds the bundled Rust collector first (needs the Rust toolchain), then copies
# the release binary into the package so kpackagetool6 ships it with the widget.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$DIR/package"
ID="org.marko.claudeusage"
BIN="claude-usage-collector"

# --- Build the Rust collector and bundle it into the package -----------------
if ! command -v cargo >/dev/null 2>&1; then
    echo "error: 'cargo' not found. Install the Rust toolchain (https://rustup.rs) and retry." >&2
    exit 1
fi

echo "Building $BIN (release) ..."
cargo build --release --manifest-path "$DIR/collector/Cargo.toml"
install -Dm755 "$DIR/collector/target/release/$BIN" "$PKG/contents/code/$BIN"

# --- Install / upgrade the plasmoid -----------------------------------------
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
