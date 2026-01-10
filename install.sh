#!/bin/bash
# install.sh - Setup fuer X-Root Mounter (Version 9.0)

LOGFILE="/tmp/xroot_install.log"
rm -f "$LOGFILE"

if [[ "$*" == *"--log"* ]]; then
    exec > >(tee -a "$LOGFILE") 2>&1
    echo "--- LOG START: $(date) ---"
fi

zenity --question --title="X-Root Installation" --text="Wollen Sie mit der Installation von X-Root Mounter fortfahren?" || exit 0

USER_NAME=$(id -un)
USER_HOME=$(eval echo ~$USER_NAME)
BIN_DIR="$USER_HOME/.local/bin"
CONFIG_DIR="$USER_HOME/.config/rootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

CODENAME=$(lsb_release -cs)
echo "System-Basis: $CODENAME"

# 1. Software & Robuster GPG-Fix
sudo apt-get update
sudo apt-get install -y flatpak curl zenity xdg-user-dirs software-properties-common gpg

# Cryptomator (Flatpak)
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub org.cryptomator.Cryptomator

# Insync Schluessel-Fix (Gezielter Import des Key ACCAF35C)
sudo mkdir -p /etc/apt/keyrings
sudo gpg --no-default-keyring --keyring /etc/apt/keyrings/insync.gpg --keyserver keyserver.ubuntu.com --recv-keys ACCAF35C
echo "deb [signed-by=/etc/apt/keyrings/insync.gpg] http://apt.insync.io/ubuntu $CODENAME non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list

sudo apt-get update
sudo apt-get install -y insync

# 2. Skripte & Config
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# 3. Starter
cat <<EOF > "$USER_HOME/.local/share/applications/xrootmounter.desktop"
[Desktop Entry]
Name=X-Root Mounter
Exec=$BIN_DIR/xrootmounter
Icon=drive-harddisk
Type=Application
Terminal=false
Categories=System;Utility;SystemTools;
EOF

update-desktop-database "$USER_HOME/.local/share/applications"

if [[ "$*" == *"--log"* ]]; then
    zenity --info --text="Installation beendet. Log wird geoeffnet."
    xdg-open "$LOGFILE"
fi

"$BIN_DIR/xrootmounter" &
