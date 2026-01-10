#!/bin/bash
# install.sh - Robustes Setup fuer X-Root Mounter

LOGFILE="/tmp/xroot_install.log"
if [[ "$*" == *"--log"* ]]; then
    exec > >(tee -a "$LOGFILE") 2>&1
    echo "--- LOG START: $(date) ---"
fi

USER_NAME=$(id -un)
USER_HOME=$(eval echo ~$USER_NAME)
BIN_DIR="$USER_HOME/.local/bin"
CONFIG_DIR="$USER_HOME/.config/rootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

# Korrekte System-Basis ermitteln
CODENAME=$(lsb_release -cs)
echo "System-Basis erkannt: $CODENAME"

# 1. Software Installation
sudo apt-get update
sudo apt-get install -y flatpak curl zenity xdg-user-dirs software-properties-common gpg

# Cryptomator
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub org.cryptomator.Cryptomator

# Insync Schluessel-Fix: Direkter Download des Keys
sudo mkdir -p /usr/share/keyrings
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/insync-archive-keyring.gpg --keyserver keyserver.ubuntu.com --recv-keys ACCAF35C

# Insync Repo mit korrekter Basis (noble/jammy)
echo "deb [signed-by=/usr/share/keyrings/insync-archive-keyring.gpg] http://apt.insync.io/ubuntu $CODENAME non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list

sudo apt-get update
sudo apt-get install -y insync

# 2. Skripte laden & Pfade sicherstellen
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
rm -f "$BIN_DIR/xrootmounter" # Alte Version loeschen
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# 3. Desktop Starter mit absolutem Pfad
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

# Abschluss
if [[ "$*" == *"--log"* ]]; then
    zenity --info --text="Installation beendet. Falls Insync immer noch fehlt, pruefe das Log."
    xdg-open "$LOGFILE"
fi

# App gezielt starten
nohup "$BIN_DIR/xrootmounter" >/dev/null 2>&1 &
