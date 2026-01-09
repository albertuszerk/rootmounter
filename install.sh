#!/bin/bash
# install.sh - Setup fuer X-Root Mounter (Version 4.0)

REAL_USER=$(id -un)
REAL_HOME=$(eval echo ~$REAL_USER)
BIN_DIR="$REAL_HOME/.local/bin"
CONFIG_DIR="$REAL_HOME/.config/rootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

# Zorin OS nutzt Ubuntu-Basis. Wir ermitteln die Basis (focal oder jammy)
UBUNTU_CODENAME=$(grep UBUNTU_CODENAME /etc/os-release | cut -d= -f2)
[ -z "$UBUNTU_CODENAME" ] && UBUNTU_CODENAME="jammy"

echo "Starte System-Vorbereitung fuer $UBUNTU_CODENAME..."

# 1. Software Repositories
sudo apt-get install -y software-properties-common curl
sudo add-apt-repository ppa:sebastian-stenzel/cryptomator -y

# Insync Repo Fix fuer Zorin
curl -s https://auth.insync.io/keys/insync.asc | sudo gpg --dearmor --yes -o /usr/share/keyrings/insync-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/insync-archive-keyring.gpg] http://apt.insync.io/ubuntu $UBUNTU_CODENAME non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list

sudo apt-get update
sudo apt-get install -y cryptomator insync zenity xdg-user-dirs

# 2. Ordner loeschen & Geisterordner fixen
for folder in Bilder Videos Musik Dokumente Vorlagen Oeffentlich; do
    rm -rf "$REAL_HOME/$folder"
done

# XDG Pfade auf Home umbiegen (versteckt sie im Menue)
xdg-user-dirs-update --set PICTURES "$REAL_HOME"
xdg-user-dirs-update --set VIDEOS "$REAL_HOME"
xdg-user-dirs-update --set MUSIC "$REAL_HOME"
xdg-user-dirs-update --set DOCUMENTS "$REAL_HOME"

# Seitenleiste (Bookmarks) bereinigen & neue Verzeichnisse hinzufuegen
BOOKMARKS="$REAL_HOME/.config/gtk-3.0/bookmarks"
mkdir -p "$(dirname "$BOOKMARKS")"
echo "file://$REAL_HOME/root root" > "$BOOKMARKS"
echo "file://$REAL_HOME/workspace workspace" >> "$BOOKMARKS"

# 3. Skripte laden
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# 4. Desktop Verknuepfungen erstellen (Sichtbarkeit auf Desktop)
DESKTOP_DIR=$(xdg-user-dir DESKTOP)
mkdir -p "$REAL_HOME/root" "$REAL_HOME/workspace"
ln -sf "$REAL_HOME/root" "$DESKTOP_DIR/root"
ln -sf "$REAL_HOME/workspace" "$DESKTOP_DIR/workspace"

# 5. Config Erstellung
cat <<EOF > "$CONFIG_DIR/config.ini"
[Hardware]
UUID=UNBEKANNT
MOUNT_POINT=/mnt/m2_root

[Structure]
ROOT_SUBFOLDERS=backup,client,clientpic,clientshare1,control,db,document,gallery,project,replicate,shareprg,softinst,softinst-shared,temp,template,web,whitepaper
WORKSPACE_SUBFOLDERS=user-backup,user-control,user-db,user-document,user-download,user-favorites,user-gallery,user-template,user-web
EOF

# 6. Desktop Starter & Menue-Refresh
cat <<EOF > "$REAL_HOME/.local/share/applications/xrootmounter.desktop"
[Desktop Entry]
Name=X-Root Mounter
Exec=$BIN_DIR/xrootmounter
Icon=drive-harddisk
Type=Application
Terminal=false
Categories=System;Utility;
EOF

sudo update-desktop-database
update-desktop-database "$REAL_HOME/.local/share/applications"

zenity --info --title="Setup abgeschlossen" --text="X-Root Setup erfolgreich!\n\n- Cryptomator & Insync installiert.\n- root & workspace Ordner auf dem Desktop sichtbar.\n- Starter im Menue verfuegbar.\n\nKlicke OK fuer die Hauptmaske."
$BIN_DIR/xrootmounter &
