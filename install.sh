#!/bin/bash
# install.sh - X-Root Mounter Setup (Version 8.0)

LOGFILE="/tmp/xroot_install.log"
rm -f "$LOGFILE" # Altes Log loeschen

if [[ "$*" == *"--log"* ]]; then
    exec > >(tee -a "$LOGFILE") 2>&1
    echo "--- LOG START: $(date) ---"
fi

# Vorab-Abfrage
zenity --question --title="X-Root Installation" --text="Wollen Sie mit der Installation von X-Root Mounter fortfahren?" || exit 0

USER_NAME=$(id -un)
USER_HOME=$(eval echo ~$USER_NAME)
BIN_DIR="$USER_HOME/.local/bin"
CONFIG_DIR="$USER_HOME/.config/rootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

# System-Basis ermitteln
CODENAME=$(lsb_release -cs)
echo "System-Basis: $CODENAME"

# 1. Software & GPG Fix
sudo apt-get update
sudo apt-get install -y flatpak curl zenity xdg-user-dirs software-properties-common gpg

# Cryptomator via Flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub org.cryptomator.Cryptomator

# Insync Schluessel-Fix (Direkt-Import) 
sudo mkdir -p /etc/apt/keyrings
curl -s https://auth.insync.io/keys/insync.asc | sudo gpg --dearmor --yes -o /etc/apt/keyrings/insync.gpg
echo "deb [signed-by=/etc/apt/keyrings/insync.gpg] http://apt.insync.io/ubuntu $CODENAME non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list

sudo apt-get update
sudo apt-get install -y insync

# 2. Skripte laden
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# Standard-Config
if [ ! -f "$CONFIG_DIR/config.ini" ]; then
cat <<EOF > "$CONFIG_DIR/config.ini"
[Hardware]
UUID=UNBEKANNT
MOUNT_POINT=/mnt/m2_root
[StandardFolders]
NAMES=Bilder,Videos,Musik,Dokumente,Vorlagen,Oeffentlich
[Structure]
ROOT_SUBFOLDERS=backup,client,clientpic,clientshare1,control,db,document,gallery,project,replicate,shareprg,softinst,softinst-shared,temp,template,web,whitepaper
WORKSPACE_SUBFOLDERS=user-backup,user-control,user-db,user-document,user-download,user-favorites,user-gallery,user-template,user-web
EOF
fi

# 3. Desktop Starter (Systemwerkzeuge)
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

nohup "$BIN_DIR/xrootmounter" >/dev/null 2>&1 &
