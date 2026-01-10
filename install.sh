#!/bin/bash
# install.sh - X-Root Mounter Setup (Version 18.0)

LOGFILE="/tmp/xroot_install.log"
rm -f "$LOGFILE" # Log automatisch bereinigen

if [[ "$*" == *"--log"* ]]; then
    exec > >(tee -a "$LOGFILE") 2>&1
    echo "--- LOG START: $(date) ---"
fi

# 1. Desktop-Pfad Fix (Radikale Aufraeumung)
USER_HOME=$HOME
# Wir biegen die Pfade auf einen versteckten Ordner um, damit sie vom Desktop verschwinden
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

# 2. Software & Insync GPG-Fix (Direkt-Import ohne dirmngr)
sudo apt update
sudo apt install -y curl gpg wget zenity xdg-user-dirs flatpak

echo "Lade Insync Schluessel herunter..."
sudo mkdir -p /etc/apt/keyrings
# Wir laden den Key direkt herunter und dearmoren ihn ohne dirmngr-Abhaengigkeit
wget -qO- https://auth.insync.io/keys/insync.asc | sudo gpg --dearmor --yes -o /etc/apt/keyrings/insync.gpg

echo "deb [signed-by=/etc/apt/keyrings/insync.gpg] http://apt.insync.io/ubuntu noble non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list
sudo apt update
sudo apt install -y insync

# 3. Skripte & Config laden (Wir ueberschreiben die .ini, um das neue Format zu erzwingen)
BIN_DIR="$USER_HOME/.local/bin"
CONFIG_DIR="$USER_HOME/.config/rootmounter"
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
curl -sL "https://raw.githubusercontent.com/albertuszerk/rootmounter/main/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# UUID aus der alten Datei retten
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

# Starter
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
