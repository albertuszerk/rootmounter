#!/bin/bash
# install.sh - Installer fuer X-Root Mounter (Version 6.0)

USER_NAME=$(id -un)
USER_HOME=$(eval echo ~$USER_NAME)
BIN_DIR="$USER_HOME/.local/bin"
CONFIG_DIR="$USER_HOME/.config/rootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

echo "Installiere Basis-Software..."
sudo apt-get update
sudo apt-get install -y flatpak curl zenity xdg-user-dirs software-properties-common

# Cryptomator via Flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub org.cryptomator.Cryptomator

# Insync Repository (Stabile Methode fuer Zorin/Ubuntu)
curl -s https://auth.insync.io/keys/insync.asc | sudo gpg --dearmor --yes -o /usr/share/keyrings/insync-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/insync-archive-keyring.gpg] http://apt.insync.io/ubuntu $(lsb_release -cs) non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list
sudo apt-get update
sudo apt-get install -y insync

# App-Files laden
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# Standard-Config erstellen
if [ ! -f "$CONFIG_DIR/config.ini" ]; then
cat <<EOF > "$CONFIG_DIR/config.ini"
[Hardware]
UUID=UNBEKANNT
MOUNT_POINT=/mnt/m2_root

[Structure]
ROOT_SUBFOLDERS=backup,client,clientpic,clientshare1,control,db,document,gallery,project,replicate,shareprg,softinst,softinst-shared,temp,template,web,whitepaper
WORKSPACE_SUBFOLDERS=user-backup,user-control,user-db,user-document,user-download,user-favorites,user-gallery,user-template,user-web
EOF
fi

# Desktop Starter
cat <<EOF > "$USER_HOME/.local/share/applications/xrootmounter.desktop"
[Desktop Entry]
Name=X-Root Mounter
Exec=$BIN_DIR/xrootmounter
Icon=drive-harddisk
Type=Application
Terminal=false
Categories=System;Utility;
EOF

update-desktop-database "$USER_HOME/.local/share/applications"

zenity --info --title="Setup abgeschlossen" --text="X-Root Setup war erfolgreich!\n\n- Cryptomator & Insync wurden installiert.\n- Starter-Icon ist im System-Menue verfuegbar.\n\nKlicke OK fuer die Hauptmaske."
$BIN_DIR/xrootmounter &
