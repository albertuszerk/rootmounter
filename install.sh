#!/bin/bash
# install.sh - Finales Setup fuer X-Root Mounter

REAL_USER=$USER
REAL_HOME=$HOME
BIN_DIR="$REAL_HOME/.local/bin"
CONFIG_DIR="$REAL_HOME/.config/rootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

echo "Starte System-Vorbereitung..."

# 1. Software Repositories und Installation
sudo add-apt-repository ppa:sebastian-stenzel/cryptomator -y
curl -s https://auth.insync.io/keys/insync.asc | sudo gpg --dearmor -o /usr/share/keyrings/insync-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/insync-archive-keyring.gpg] http://apt.insync.io/ubuntu $(lsb_release -cs) non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list

sudo apt-get update
sudo apt-get install -y cryptomator insync zenity xdg-user-dirs

# 2. Physische Loeschung und System-Konfiguration (Geisterordner fixen)
echo "Bereinige Standard-Verzeichnisse und Seitenleiste..."
for folder in Bilder Videos Musik Dokumente Vorlagen Oeffentlich; do
    rm -rf "$REAL_HOME/$folder"
done

# Die Konfigurationsdatei fuer die Seitenleiste anpassen
xdg-user-dirs-update --set PICTURES "$REAL_HOME"
xdg-user-dirs-update --set VIDEOS "$REAL_HOME"
xdg-user-dirs-update --set MUSIC "$REAL_HOME"
xdg-user-dirs-update --set DOCUMENTS "$REAL_HOME"
xdg-user-dirs-update --set TEMPLATES "$REAL_HOME"
xdg-user-dirs-update --set PUBLICSHARE "$REAL_HOME"

# 3. Download und Rechte
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# 4. Standard-Config erstellen
cat <<EOF > "$CONFIG_DIR/config.ini"
[Hardware]
UUID=UNBEKANNT
MOUNT_POINT=/mnt/m2_root

[Structure]
ROOT_SUBFOLDERS=backup,client,clientpic,clientshare1,control,db,document,gallery,project,replicate,shareprg,softinst,softinst-shared,temp,template,web,whitepaper
WORKSPACE_SUBFOLDERS=user-backup,user-control,user-db,user-document,user-download,user-favorites,user-gallery,user-template,user-web
EOF

# 5. Desktop-Starter
cat <<EOF > "$REAL_HOME/.local/share/applications/xrootmounter.desktop"
[Desktop Entry]
Name=X-Root Mounter
Exec=$BIN_DIR/xrootmounter
Icon=drive-harddisk
Type=Application
Terminal=false
Categories=System;Utility;
EOF

# Menues aktualisieren, damit Icons erscheinen
update-desktop-database "$REAL_HOME/.local/share/applications"

# 6. Abschlussmaske
zenity --info --title="Setup abgeschlossen" --text="X-Root Setup war erfolgreich!\n\n- Cryptomator & Insync wurden installiert.\n- Das Starter-Icon ist jetzt im System-Menue verfuegbar.\n- Standardordner wurden entfernt.\n\nKlicke OK, um die Hauptmaske zu oeffnen."

# Hauptmaske direkt starten
$BIN_DIR/xrootmounter &
