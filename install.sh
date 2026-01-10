#!/bin/bash
# install.sh - X-Root Mounter Setup (Version 14.0)

LOGFILE="/tmp/xroot_install.log"
rm -f "$LOGFILE" # Altes Log automatisch loeschen 

if [[ "$*" == *"--log"* ]]; then
    exec > >(tee -a "$LOGFILE") 2>&1
    echo "--- LOG START: $(date) ---"
fi

zenity --question --title="X-Root Installation" --text="Moechten Sie mit der Installation fortfahren?" || exit 0

USER_HOME=$HOME
BIN_DIR="$USER_HOME/.local/bin"
CONFIG_DIR="$USER_HOME/.config/rootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

# 1. Software & Direkter Insync-Key Fix (Vermeidet )
sudo apt update
sudo apt install -y curl gpg wget zenity xdg-user-dirs flatpak

# Insync Schluessel ohne Umwege direkt in den Keyring schreiben
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://auth.insync.io/keys/insync.asc | sudo gpg --dearmor --yes -o /usr/share/keyrings/insync-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/insync-archive-keyring.gpg] http://apt.insync.io/ubuntu noble non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list
sudo apt update
sudo apt install -y insync

# 2. Skripte laden
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# 3. Die neue, selbsterklaerende .ini
if [ ! -f "$CONFIG_DIR/config.ini" ]; then
cat <<EOF > "$CONFIG_DIR/config.ini"
[Hardware]
UUID=UNBEKANNT
MOUNT_POINT=/mnt/m2_root

[StandardFolders]
# Diese Ordner werden geloescht, wenn sie leer sind.
NAMES=Bilder,Videos,Musik,Dokumente,Vorlagen,Oeffentlich

[Roots]
# Definition der Hauptordner und ihrer Icon-Farben.
# Format: Ordnername:Farbe (Moeglich: blue, green, red, yellow, violet, grey)
# Beispiel fuer Erweiterung: MAIN_FOLDERS=root:blue,workspace:green,workspace2:violet,workspace3:red
MAIN_FOLDERS=root:blue,workspace:green,workspace2:violet

[Subfolders]
# Hier definierst du die Unterordner fuer JEDEN oben genannten Hauptordner.
root=backup,client,clientpic,control,db,document,project,web
workspace=user-backup,user-control,user-db,user-document
workspace2=test1,test2,test3
EOF
fi

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
