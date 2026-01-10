#!/bin/bash
# install.sh - X-Root Mounter Setup (Version 30.0)

LOGFILE="/tmp/xroot_install.log"
rm -f "$LOGFILE"

if [[ "$*" == *"--log"* ]]; then
    exec > >(tee -a "$LOGFILE") 2>&1
    echo "--- LOG START: $(date) ---"
fi

zenity --question --title="X-Root Installation" --text="Moechten Sie mit der Installation von X-Root Mounter fortfahren?" || exit 0

USER_HOME=$HOME
BIN_DIR="$USER_HOME/.local/bin"
CONFIG_DIR="$USER_HOME/.config/rootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

# USB-Autosuspend deaktivieren
sudo mkdir -p /etc/modprobe.d/
echo "options usbcore autosuspend=-1" | sudo tee /etc/modprobe.d/disable-usb-autosuspend.conf > /dev/null

# Software & Desktop Pfade
sudo apt update
sudo apt install -y curl gpg wget zenity xdg-user-dirs flatpak
# (Insync Key-Routine hier einfügen wie in v29.0)

HIDDEN_BASE="$USER_HOME/.local/share/xroot_hidden"
mkdir -p "$HIDDEN_BASE"/{Bilder,Videos,Musik,Dokumente,Vorlagen,Oeffentlich}
mkdir -p "$USER_HOME/Schreibtisch"

cat <<EOF > "$USER_HOME/.config/user-dirs.dirs"
XDG_DESKTOP_DIR="\$HOME/Schreibtisch"
XDG_DOWNLOAD_DIR="\$HOME/Downloads"
XDG_TEMPLATES_DIR="\$HIDDEN_BASE/Vorlagen"
XDG_PUBLICSHARE_DIR="\$HIDDEN_BASE/Oeffentlich"
XDG_DOCUMENTS_DIR="\$HIDDEN_BASE/Dokumente"
XDG_MUSIC_DIR="\$HIDDEN_BASE/Musik"
XDG_PICTURES_DIR="\$HIDDEN_BASE/Bilder"
XDG_VIDEOS_DIR="\$HIDDEN_BASE/Videos"
EOF

# Skripte laden
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# INI-Format
OLD_UUID=$(grep "UUID=" "$CONFIG_DIR/config.ini" 2>/dev/null | cut -d'=' -f2)
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
xdg-user-dirs-update --force
rm -f /tmp/xrootmounter.lock
nohup "$BIN_DIR/xrootmounter" >/dev/null 2>&1 &
