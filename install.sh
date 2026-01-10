#!/bin/bash
# install.sh - X-Root Mounter Setup (Version 17.0)

LOGFILE="/tmp/xroot_install.log"
rm -f "$LOGFILE"

if [[ "$*" == *"--log"* ]]; then
    exec > >(tee -a "$LOGFILE") 2>&1
    echo "--- LOG START: $(date) ---" [cite: 1]
fi

USER_HOME=$HOME
BIN_DIR="$USER_HOME/.local/bin"
CONFIG_DIR="$USER_HOME/.config/rootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

# 1. Desktop-Pfad Fix (Radikale Aufraeumung)
# Wir biegen Standardordner auf ein verstecktes Verzeichnis um
mkdir -p "$USER_HOME/Schreibtisch"
HIDDEN_BASE="$USER_HOME/.local/share/xroot_hidden"
mkdir -p "$HIDDEN_BASE"/{Bilder,Videos,Musik,Dokumente,Vorlagen,Oeffentlich}

cat <<EOF > "$USER_HOME/.config/user-dirs.dirs"
XDG_DESKTOP_DIR="\$HOME/Schreibtisch"
XDG_DOWNLOAD_DIR="\$HOME/Downloads"
XDG_TEMPLATES_DIR="\$HOME/.local/share/xroot_hidden/Vorlagen"
XDG_PUBLICSHARE_DIR="\$HOME/.local/share/xroot_hidden/Oeffentlich"
XDG_DOCUMENTS_DIR="\$HOME/.local/share/xroot_hidden/Dokumente"
XDG_MUSIC_DIR="\$HOME/.local/share/xroot_hidden/Musik"
XDG_PICTURES_DIR="\$HOME/.local/share/xroot_hidden/Bilder"
XDG_VIDEOS_DIR="\$HOME/.local/share/xroot_hidden/Videos"
EOF

# 2. Software & Insync Fix (Alternative Key-Import Methode)
sudo apt update
sudo apt install -y curl gpg wget zenity xdg-user-dirs flatpak [cite: 5, 6, 7]

echo "Lade Insync Schluessel herunter..."
sudo mkdir -p /usr/share/keyrings
# Wir laden den Key direkt vom Keyserver, um curl-Probleme zu umgehen
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/insync-archive-keyring.gpg --keyserver keyserver.ubuntu.com --recv-keys ACCAF35C

echo "deb [signed-by=/usr/share/keyrings/insync-archive-keyring.gpg] http://apt.insync.io/ubuntu noble non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list
sudo apt update
sudo apt install -y insync

# 3. Skripte & Config laden (Wir erzwingen das neue Format)
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# UUID retten falls vorhanden (sdc3 etc. wird in echte UUID gewandelt)
OLD_UUID=$(grep "UUID=" "$CONFIG_DIR/config.ini" 2>/dev/null | cut -d'=' -f2)

cat <<EOF > "$CONFIG_DIR/config.ini"
[Hardware]
UUID=${OLD_UUID:-UNBEKANNT}
MOUNT_POINT=/mnt/m2_root

[StandardFolders]
NAMES=Bilder,Videos,Musik,Dokumente,Vorlagen,Oeffentlich

[Roots]
# Format: Name:Farbe
MAIN_FOLDERS=root:blue,workspace:green,workspace2:violet

[Subfolders]
root=backup,client,clientpic,control,db,document,project,web
workspace=user-backup,user-control,user-db,user-document
workspace2=test1,test2,test3
EOF

# 4. Starter
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
xdg-user-dirs-update
[[ "$*" == *"--log"* ]] && xdg-open "$LOGFILE"
nohup "$BIN_DIR/xrootmounter" >/dev/null 2>&1 &
