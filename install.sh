#!/bin/bash
# install.sh - X-Root Mounter Setup (Version 5.0)

USER_NAME=$(id -un)
USER_HOME=$(eval echo ~$USER_NAME)
BIN_DIR="$USER_HOME/.local/bin"
CONFIG_DIR="$USER_HOME/.config/rootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

# 1. System-Vorbereitung und Software
# Wir nutzen die stabilste Insync-Version fuer Zorin/Ubuntu
echo "Installiere Software (Cryptomator & Insync)..."
sudo apt-get update
sudo apt-get install -y flatpak curl zenity xdg-user-dirs

# Cryptomator via Flatpak (Sicherer und isoliert)
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub org.cryptomator.Cryptomator

# Insync Desktop via DEB (Jammy/Zorin-kompatibel)
curl -L -o /tmp/insync.deb https://cdn.insynchq.com/builds/linux/3.8.4.50481/insync_3.8.4.50481-jammy_amd64.deb
sudo apt-get install -y /tmp/insync.deb

# 2. Radikale Geisterordner-Bereinigung (Menue & Seitenleiste)
echo "Bereinige Standardverzeichnisse..."
for folder in Bilder Videos Musik Dokumente Vorlagen Oeffentlich; do
    rm -rf "$USER_HOME/$folder"
done

# Zwingt das System, diese Pfade zu vergessen (auch im Menue)
cat <<EOF > "$USER_HOME/.config/user-dirs.dirs"
XDG_DESKTOP_DIR="\$HOME/Desktop"
XDG_DOWNLOAD_DIR="\$HOME/Downloads"
XDG_TEMPLATES_DIR="\$HOME"
XDG_PUBLICSHARE_DIR="\$HOME"
XDG_DOCUMENTS_DIR="\$HOME"
XDG_MUSIC_DIR="\$HOME"
XDG_PICTURES_DIR="\$HOME"
XDG_VIDEOS_DIR="\$HOME"
EOF

# Seitenleiste (Bookmarks) saeubern
BOOKMARKS="$USER_HOME/.config/gtk-3.0/bookmarks"
echo "file://$USER_HOME/root root" > "$BOOKMARKS"
echo "file://$USER_HOME/workspace workspace" >> "$BOOKMARKS"

# 3. Desktop-Links fuer Sichtbarkeit
DESKTOP_PATH=$(xdg-user-dir DESKTOP)
mkdir -p "$USER_HOME/root" "$USER_HOME/workspace"
ln -sf "$USER_HOME/root" "$DESKTOP_PATH/root"
ln -sf "$USER_HOME/workspace" "$DESKTOP_PATH/workspace"

# 4. App-Struktur laden
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# Standard-Config
cat <<EOF > "$CONFIG_DIR/config.ini"
[Hardware]
UUID=UNBEKANNT
MOUNT_POINT=/mnt/m2_root
[Structure]
ROOT_SUBFOLDERS=backup,client,clientpic,clientshare1,control,db,document,gallery,project,replicate,shareprg,softinst,softinst-shared,temp,template,web,whitepaper
WORKSPACE_SUBFOLDERS=user-backup,user-control,user-db,user-document,user-download,user-favorites,user-gallery,user-template,user-web
EOF

# 5. Menue-Starter erstellen
cat <<EOF > "$USER_HOME/.local/share/applications/xrootmounter.desktop"
[Desktop Entry]
Name=X-Root Mounter
Exec=$BIN_DIR/xrootmounter
Icon=drive-harddisk
Type=Application
Terminal=false
Categories=System;Utility;
EOF

sudo update-desktop-database
update-desktop-database "$USER_HOME/.local/share/applications"

# Abschlussmaske
zenity --info --title="Setup abgeschlossen" --text="X-Root Setup war erfolgreich!\n\n- Cryptomator (Flatpak) & Insync (DEB) installiert.\n- root & workspace Ordner sind auf dem Desktop.\n- Geisterordner wurden aus dem Menue entfernt.\n\nKlicke OK fuer die Hauptmaske."

$BIN_DIR/xrootmounter &
