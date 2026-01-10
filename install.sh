#!/bin/bash
# install.sh - Setup fuer X-Root Mounter mit Logging

LOGFILE="/tmp/xroot_install.log"
if [[ "$*" == *"--log"* ]]; then
    exec > >(tee -a "$LOGFILE") 2>&1
    echo "--- LOG START: $(date) ---"
fi

REAL_USER=$(id -un)
REAL_HOME=$(eval echo ~$REAL_USER)
BIN_DIR="$REAL_HOME/.local/bin"
CONFIG_DIR="$REAL_HOME/.config/rootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

# Zorin Basis ermitteln
BASE_VER=$(lsb_release -cs)
case "$BASE_VER" in
    "jammy"|"zorin") CODENAME="jammy" ;;
    "focal") CODENAME="focal" ;;
    *) CODENAME="jammy" ;;
esac

echo "System-Vorbereitung fuer $CODENAME..."

# 1. Software Installation
sudo apt-get update
sudo apt-get install -y flatpak curl zenity xdg-user-dirs software-properties-common

# Cryptomator
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub org.cryptomator.Cryptomator

# Cryptomator Kategorie anpassen (Systemwerkzeuge)
FILE_PATH="/var/lib/flatpak/exports/share/applications/org.cryptomator.Cryptomator.desktop"
if [ -f "$FILE_PATH" ]; then
    sudo sed -i 's/Categories=.*/Categories=System;Utility;SystemTools;/' "$FILE_PATH"
fi

# Insync
curl -s https://auth.insync.io/keys/insync.asc | sudo gpg --dearmor --yes -o /usr/share/keyrings/insync-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/insync-archive-keyring.gpg] http://apt.insync.io/ubuntu $CODENAME non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list
sudo apt-get update
sudo apt-get install -y insync

# 2. Config & Skripte
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# Standard-Config mit Standard-Ordnern
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

# Desktop Starter
cat <<EOF > "$REAL_HOME/.local/share/applications/xrootmounter.desktop"
[Desktop Entry]
Name=X-Root Mounter
Exec=$BIN_DIR/xrootmounter
Icon=drive-harddisk
Type=Application
Terminal=false
Categories=System;Utility;
EOF

update-desktop-database "$REAL_HOME/.local/share/applications"

if [[ "$*" == *"--log"* ]]; then
    zenity --info --text="Installation beendet. Das Log wird nun geoeffnet."
    xdg-open "$LOGFILE"
fi

$BIN_DIR/xrootmounter &
