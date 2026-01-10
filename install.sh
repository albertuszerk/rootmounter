#!/bin/bash
# install.sh - X-Root Mounter Setup (Version 13.0)

LOGFILE="/tmp/xroot_install.log"
rm -f "$LOGFILE"

# Log-Funktion aktivieren, wenn --log uebergeben wurde
if [[ "$*" == *"--log"* ]]; then
    exec > >(tee -a "$LOGFILE") 2>&1
    echo "--- LOG START: $(date) ---"
fi

# Vorab-Abfrage
zenity --question --title="X-Root Installation" --text="Wollen Sie mit der Installation von X-Root Mounter fortfahren?" || exit 0

USER_HOME=$HOME
BIN_DIR="$USER_HOME/.local/bin"
CONFIG_DIR="$USER_HOME/.config/rootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

# 1. Desktop-Pfad reparieren (Desktop-Muell entfernen)
# Wir biegen die Standardordner in ein Unterverzeichnis im Home um
mkdir -p "$USER_HOME/Schreibtisch"
mkdir -p "$USER_HOME/.local/share/xroot_backup"
cat <<EOF > "$USER_HOME/.config/user-dirs.dirs"
XDG_DESKTOP_DIR="\$HOME/Schreibtisch"
XDG_DOWNLOAD_DIR="\$HOME/Downloads"
XDG_TEMPLATES_DIR="\$HOME/.local/share/xroot_backup"
XDG_PUBLICSHARE_DIR="\$HOME/.local/share/xroot_backup"
XDG_DOCUMENTS_DIR="\$HOME/.local/share/xroot_backup"
XDG_MUSIC_DIR="\$HOME/.local/share/xroot_backup"
XDG_PICTURES_DIR="\$HOME/.local/share/xroot_backup"
XDG_VIDEOS_DIR="\$HOME/.local/share/xroot_backup"
EOF

# 2. Software & Insync Fix (Der "GPG-Killer")
sudo apt update
sudo apt install -y curl gpg wget zenity xdg-user-dirs

# Insync Schluessel sauber importieren
sudo mkdir -p /usr/share/keyrings
# Wir laden die Datei erst lokal herunter, um Pipe-Fehler zu vermeiden
curl -L -s https://auth.insync.io/keys/insync.asc -o /tmp/insync.asc
sudo gpg --dearmor --yes -o /usr/share/keyrings/insync-archive-keyring.gpg /tmp/insync.asc

echo "deb [signed-by=/usr/share/keyrings/insync-archive-keyring.gpg] http://apt.insync.io/ubuntu noble non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list
sudo apt update
sudo apt install -y insync

# Cryptomator via Flatpak
sudo apt install -y flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub org.cryptomator.Cryptomator

# 3. Skripte & Config laden
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
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

[[ "$*" == *"--log"* ]] && xdg-open "$LOGFILE"
nohup "$BIN_DIR/xrootmounter" >/dev/null 2>&1 &
