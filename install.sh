#!/bin/bash
# install.sh - X-Root Mounter Setup (Version 12.0)

LOGFILE="/tmp/xroot_install.log"
rm -f "$LOGFILE" [cite: 1]

if [[ "$*" == *"--log"* ]]; then
    exec > >(tee -a "$LOGFILE") 2>&1
    echo "--- LOG START: $(date) ---"
fi

# 1. Desktop-Pfad Fix (Schreibtisch wiederherstellen)
USER_HOME=$HOME
mkdir -p "$USER_HOME/Schreibtisch"
cat <<EOF > "$USER_HOME/.config/user-dirs.dirs"
XDG_DESKTOP_DIR="\$HOME/Schreibtisch"
XDG_DOWNLOAD_DIR="\$HOME/Downloads"
XDG_TEMPLATES_DIR="\$HOME/.local/share/xroot/templates"
XDG_PUBLICSHARE_DIR="\$HOME/.local/share/xroot/public"
XDG_DOCUMENTS_DIR="\$HOME/.local/share/xroot/docs"
XDG_MUSIC_DIR="\$HOME/.local/share/xroot/music"
XDG_PICTURES_DIR="\$HOME/.local/share/xroot/pics"
XDG_VIDEOS_DIR="\$HOME/.local/share/xroot/vids"
EOF
mkdir -p "$USER_HOME/.local/share/xroot"/{templates,public,docs,music,pics,vids}

# 2. Software & Insync Schluessel (Sicherer Weg)
sudo apt update
sudo apt install -y curl gpg wget [cite: 5, 6]
echo "Lade Insync Schluessel herunter..."
curl -sL https://auth.insync.io/keys/insync.asc > /tmp/insync.asc
if [ -s /tmp/insync.asc ]; then
    sudo gpg --dearmor --yes -o /usr/share/keyrings/insync-archive-keyring.gpg /tmp/insync.asc
    echo "deb [signed-by=/usr/share/keyrings/insync-archive-keyring.gpg] http://apt.insync.io/ubuntu noble non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list
    sudo apt update
    sudo apt install -y insync
fi

# 3. Skripte laden
BIN_DIR="$USER_HOME/.local/bin"
mkdir -p "$BIN_DIR"
curl -sL "https://raw.githubusercontent.com/albertuszerk/rootmounter/main/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

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
"$BIN_DIR/xrootmounter" &
