#!/bin/bash
# install.sh - Setup mit Flatpak und DEB Download

REAL_USER=$(id -un)
REAL_HOME=$(eval echo ~$REAL_USER)
BIN_DIR="$REAL_HOME/.local/bin"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

echo "Starte Installation..."

# 1. Cryptomator via Flatpak
echo "Installiere Cryptomator via Flatpak..."
sudo apt-get install -y flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub org.cryptomator.Cryptomator

# 2. Insync via DEB (Desktop Version, nicht Headless!)
echo "Installiere Insync Desktop Version..."
# Wir laden die aktuelle Version fuer Ubuntu (Zorin Basis)
curl -L -o /tmp/insync.deb https://cdn.insynchq.com/builds/linux/3.8.4.50481/insync_3.8.4.50481-jammy_amd64.deb
sudo apt-get install -y /tmp/insync.deb

# 3. Geisterordner & Seitenleiste fixen
for folder in Bilder Videos Musik Dokumente Vorlagen Oeffentlich; do
    rm -rf "$REAL_HOME/$folder"
done
xdg-user-dirs-update --set PICTURES "$REAL_HOME"
xdg-user-dirs-update --set VIDEOS "$REAL_HOME"
BOOKMARKS="$REAL_HOME/.config/gtk-3.0/bookmarks"
echo "file://$REAL_HOME/root root" > "$BOOKMARKS"
echo "file://$REAL_HOME/workspace workspace" >> "$BOOKMARKS"

# 4. Desktop Links fuer root und workspace
DESKTOP_DIR=$(xdg-user-dir DESKTOP)
mkdir -p "$REAL_HOME/root" "$REAL_HOME/workspace"
ln -sf "$REAL_HOME/root" "$DESKTOP_DIR/root"
ln -sf "$REAL_HOME/workspace" "$DESKTOP_DIR/workspace"

# 5. Skripte laden & Starter erstellen
mkdir -p "$BIN_DIR"
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

cat <<EOF > "$REAL_HOME/.local/share/applications/xrootmounter.desktop"
[Desktop Entry]
Name=X-Root Mounter
Exec=$BIN_DIR/xrootmounter
Icon=drive-harddisk
Type=Application
Categories=System;Utility;
EOF

update-desktop-database "$REAL_HOME/.local/share/applications"

zenity --info --text="Setup mit Flatpak und DEB abgeschlossen!"
$BIN_DIR/xrootmounter &
