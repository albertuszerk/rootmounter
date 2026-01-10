#!/bin/bash
# install.sh - Setup fuer X-Root Mounter

LOGFILE="/tmp/xroot_install.log"
rm -f "$LOGFILE"

if [[ "$*" == *"--log"* ]]; then
    exec > >(tee -a "$LOGFILE") 2>&1
    echo "--- LOG START: $(date) ---"
fi

zenity --question --title="X-Root Installation" --text="Wollen Sie mit der Installation fortfahren?" || exit 0

USER_HOME=$HOME
BIN_DIR="$USER_HOME/.local/bin"
CONFIG_DIR="$USER_HOME/.config/rootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

# 1. Software & GPG Fix (Speziell fuer Ubuntu Noble)
sudo apt update
sudo apt install -y flatpak curl zenity xdg-user-dirs gpg

# Insync Schluessel-Fix
sudo mkdir -p /usr/share/keyrings
sudo curl -sL https://auth.insync.io/keys/insync.asc | sudo gpg --dearmor --yes -o /usr/share/keyrings/insync-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/insync-archive-keyring.gpg] http://apt.insync.io/ubuntu noble non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list

sudo apt update
sudo apt install -y insync
flatpak install -y flathub org.cryptomator.Cryptomator

# 2. Skripte laden
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# 3. Flexible Config (History-Support vorbereiten)
cat <<EOF > "$CONFIG_DIR/config.ini"
[Hardware]
UUID=UNBEKANNT
MOUNT_POINT=/mnt/m2_root
[StandardFolders]
NAMES=Bilder,Videos,Musik,Dokumente,Vorlagen,Oeffentlich
[Roots]
# Hier kannst du beliebig viele Hauptordner definieren
MAIN_FOLDERS=root,workspace,workspace2
[Subfolders]
root=backup,client,clientpic,control,db,document,project,web
workspace=user-backup,user-control,user-db,user-document
workspace2=test1,test2,test3
EOF

# 4. Starter erstellen
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

# Log oeffnen falls angefordert
[[ "$*" == *"--log"* ]] && xdg-open "$LOGFILE"
"$BIN_DIR/xrootmounter" &
