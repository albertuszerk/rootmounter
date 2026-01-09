#!/bin/bash
# install.sh - Einmaliges Setup fuer X-Root Mounter

# Pfade definieren
REAL_USER=$USER
REAL_HOME=$HOME
BIN_DIR="$REAL_HOME/.local/bin"
CONFIG_DIR="$REAL_HOME/.config/rootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

echo "Starte System-Vorbereitung (Software & Reinigung)..."

# 1. Software Repositories hinzufuegen
sudo add-apt-repository ppa:sebastian-stenzel/cryptomator -y
curl -s https://auth.insync.io/keys/insync.asc | sudo gpg --dearmor -o /usr/share/keyrings/insync-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/insync-archive-keyring.gpg] http://apt.insync.io/ubuntu $(lsb_release -cs) non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list

# 2. Installation
sudo apt-get update
sudo apt-get install -y cryptomator insync software-properties-common

# 3. Verzeichnisreinigung (Physisches Loeschen der Standardordner)
echo "Bereinige Standard-Verzeichnisse..."
for folder in Bilder Videos Musik Dokumente Vorlagen Oeffentlich; do
    if [ -d "$REAL_HOME/$folder" ]; then
        rm -rf "$REAL_HOME/$folder"
        echo "Geloescht: $folder"
    fi
done

# 4. Config und App laden
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# 5. Standard-Config erstellen
cat <<EOF > "$CONFIG_DIR/config.ini"
[Hardware]
UUID=UNBEKANNT
MOUNT_POINT=/mnt/m2_root

[Structure]
ROOT_SUBFOLDERS=backup,client,clientpic,clientshare1,control,db,document,gallery,project,replicate,shareprg,softinst,softinst-shared,temp,template,web,whitepaper
WORKSPACE_SUBFOLDERS=user-backup,user-control,user-db,user-document,user-download,user-favorites,user-gallery,user-template,user-web
EOF

# 6. Desktop-Starter
cat <<EOF > "$REAL_HOME/.local/share/applications/xrootmounter.desktop"
[Desktop Entry]
Name=X-Root Mounter
Exec=$BIN_DIR/xrootmounter
Icon=drive-harddisk
Type=Application
Terminal=false
Categories=System;Utility;
EOF

echo "Setup abgeschlossen. Die Apps sind nun installiert und das System ist gereinigt."
