#!/bin/bash
# install.sh - Bootstrap fuer X-Root Mounter

APP_NAME="xrootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/rootmounter"

mkdir -p "$BIN_DIR" "$CONFIG_DIR"

# Hauptskript laden
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# Vollstaendige config.ini erstellen
if [ ! -f "$CONFIG_DIR/config.ini" ]; then
cat <<EOF > "$CONFIG_DIR/config.ini"
[Hardware]
UUID=UNBEKANNT
MOUNT_POINT=/mnt/m2_root
FS_TYPE=ntfs

[Structure]
ROOT_DIRNAME=root
ROOT_SUBFOLDERS=backup,client,clientpic,clientshare1,control,db,document,gallery,project,replicate,shareprg,softinst,softinst-shared,temp,template,web,whitepaper

WORKSPACE_DIRNAME=workspace
WORKSPACE_SUBFOLDERS=user-backup,user-control,user-db,user-document,user-download,user-favorites,user-gallery,user-template,user-web
EOF
fi

# Desktop Starter erstellen
mkdir -p "$HOME/.local/share/applications"
cat <<EOF > "$HOME/.local/share/applications/xrootmounter.desktop"
[Desktop Entry]
Name=X-Root Mounter
Exec=$BIN_DIR/xrootmounter
Icon=drive-harddisk
Type=Application
Terminal=true
Categories=System;Utility;
EOF

echo "Installation bereit. Bitte starte die App ueber dein Menue."
