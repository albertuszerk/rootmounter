#!/bin/bash
# install.sh - Setup fuer X-Root Mounter (Version 3.0)

REAL_USER=$USER
REAL_HOME=$HOME
BIN_DIR="$REAL_HOME/.local/bin"
CONFIG_DIR="$REAL_HOME/.config/rootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

# 1. Software Installation
# Wir nutzen -y und sorgen dafuer, dass die Datenbanken neu aufgebaut werden
sudo add-apt-repository ppa:sebastian-stenzel/cryptomator -y
curl -s https://auth.insync.io/keys/insync.asc | sudo gpg --dearmor -o /usr/share/keyrings/insync-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/insync-archive-keyring.gpg] http://apt.insync.io/ubuntu $(lsb_release -cs) non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list

sudo apt-get update
sudo apt-get install -y cryptomator insync zenity xdg-user-dirs

# 2. Geisterordner physisch und visuell entfernen
for folder in Bilder Videos Musik Dokumente Vorlagen Oeffentlich; do
    rm -rf "$REAL_HOME/$folder"
done

# Die System-Konfiguration fuer Pfade zuruecksetzen
xdg-user-dirs-update --set DOWNLOAD "$REAL_HOME/Downloads"
xdg-user-dirs-update --set PICTURES "$REAL_HOME"
xdg-user-dirs-update --set VIDEOS "$REAL_HOME"
xdg-user-dirs-update --set MUSIC "$REAL_HOME"
xdg-user-dirs-update --set DOCUMENTS "$REAL_HOME"

# RADIKALER FIX: Die Seitenleiste (GTK Bookmarks) bereinigen
BOOKMARKS="$REAL_HOME/.config/gtk-3.0/bookmarks"
if [ -f "$BOOKMARKS" ]; then
    sed -i '/Bilder/d' "$BOOKMARKS"
    sed -i '/Videos/d' "$BOOKMARKS"
    sed -i '/Musik/d' "$BOOKMARKS"
    sed -i '/Dokumente/d' "$BOOKMARKS"
fi

# 3. Download der Skripte
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# 4. Config Erstellung
cat <<EOF > "$CONFIG_DIR/config.ini"
[Hardware]
UUID=UNBEKANNT
MOUNT_POINT=/mnt/m2_root

[Structure]
ROOT_SUBFOLDERS=backup,client,clientpic,clientshare1,control,db,document,gallery,project,replicate,shareprg,softinst,softinst-shared,temp,template,web,whitepaper
WORKSPACE_SUBFOLDERS=user-backup,user-control,user-db,user-document,user-download,user-favorites,user-gallery,user-template,user-web
EOF

# 5. Desktop Starter und Menue-Update
cat <<EOF > "$REAL_HOME/.local/share/applications/xrootmounter.desktop"
[Desktop Entry]
Name=X-Root Mounter
Exec=$BIN_DIR/xrootmounter
Icon=drive-harddisk
Type=Application
Terminal=false
Categories=System;Utility;
EOF

# System zwingen, das Menue und die Icons neu zu laden
sudo update-desktop-database
update-desktop-database "$REAL_HOME/.local/share/applications"

# 6. Abschlussmaske
zenity --info --title="Setup abgeschlossen" --text="X-Root Setup war erfolgreich!\n\n- Cryptomator & Insync installiert.\n- Geisterordner aus Seitenleiste entfernt.\n- Starter im Menue verfuegbar.\n\nKlicke OK fuer die Hauptmaske."

$BIN_DIR/xrootmounter &
