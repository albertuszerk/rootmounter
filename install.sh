#!/bin/bash
# install.sh - X-Root Mounter Setup (Version 15.0)

LOGFILE="/tmp/xroot_install.log"
rm -f "$LOGFILE"

if [[ "$*" == *"--log"* ]]; then
    exec > >(tee -a "$LOGFILE") 2>&1
    echo "--- LOG START: $(date) ---"
fi

USER_HOME=$HOME
BIN_DIR="$USER_HOME/.local/bin"
CONFIG_DIR="$USER_HOME/.config/rootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

# 1. Desktop-Pfad Fix (Radikale Aufraeumung)
# Wir stellen sicher, dass der Desktop NUR den Schreibtisch-Inhalt zeigt
mkdir -p "$USER_HOME/Schreibtisch"
cat <<EOF > "$USER_HOME/.config/user-dirs.dirs"
XDG_DESKTOP_DIR="\$HOME/Schreibtisch"
XDG_DOWNLOAD_DIR="\$HOME/Downloads"
XDG_TEMPLATES_DIR="\$HOME/.local/share/xroot_hidden"
XDG_PUBLICSHARE_DIR="\$HOME/.local/share/xroot_hidden"
XDG_DOCUMENTS_DIR="\$HOME/.local/share/xroot_hidden"
XDG_MUSIC_DIR="\$HOME/.local/share/xroot_hidden"
XDG_PICTURES_DIR="\$HOME/.local/share/xroot_hidden"
XDG_VIDEOS_DIR="\$HOME/.local/share/xroot_hidden"
EOF
mkdir -p "$USER_HOME/.local/share/xroot_hidden"

# 2. Software & Insync SSL-Bezwinger
sudo apt update
sudo apt install -y curl gpg wget zenity xdg-user-dirs flatpak

# Insync Schluessel - Wir ignorieren das SSL-Zertifikatsproblem beim Key-Download (-k)
sudo mkdir -p /usr/share/keyrings
curl -fsSLk https://auth.insync.io/keys/insync.asc | sudo gpg --dearmor --yes -o /usr/share/keyrings/insync-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/insync-archive-keyring.gpg] http://apt.insync.io/ubuntu noble non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list
sudo apt update
sudo apt install -y insync

# 3. Skripte & Config laden (Wir ueberschreiben die .ini fuer das neue Format)
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# UUID retten falls vorhanden
OLD_UUID=$(grep "UUID=" "$CONFIG_DIR/config.ini" | cut -d'=' -f2)

cat <<EOF > "$CONFIG_DIR/config.ini"
[Hardware]
UUID=${OLD_UUID:-UNBEKANNT}
MOUNT_POINT=/mnt/m2_root

[StandardFolders]
NAMES=Bilder,Videos,Musik,Dokumente,Vorlagen,Oeffentlich

[Roots]
MAIN_FOLDERS=root:blue,workspace:green,workspace2:violet

[Subfolders]
root=backup,client,clientpic,control,db,document,project,web
workspace=user-backup,user-control,user-db,user-document
workspace2=test1,test2,test3
EOF

# 4. Starter & System-Refresh
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
