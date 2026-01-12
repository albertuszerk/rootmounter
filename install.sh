#!/bin/bash
# install.sh - X-Root Mounter v1.0 Final Setup

LOGFILE="/tmp/xroot_install.log"
rm -f "$LOGFILE"

if [[ "$*" == *"--log"* ]]; then
    exec > >(tee -a "$LOGFILE") 2>&1
    echo "--- LOG START: $(date) ---"
fi

# 1. APT-Lock Prüfung (Warten auf Hintergrund-Updates)
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    zenity --info --title="System beschaeftigt" --text="Zorin OS installiert gerade Updates. Bitte warten..." --timeout=3
    sleep 5
done

# 2. Kindgerechte Start-Abfrage
DESC="Dieses Programm hilft dir, deine externe Festplatte ganz einfach anzuschliessen und deine Ordner (wie Bilder und Dokumente) schoen zu sortieren, damit dein Computer immer ordentlich bleibt.\n\nMoechten Sie mit der Installation fortfahren?"
zenity --question --title="X-Root Mounter v1.0 Installation" --text="$DESC" --width=450 || exit 0

USER_HOME=$HOME
BIN_DIR="$USER_HOME/.local/bin"
CONFIG_DIR="$USER_HOME/.config/rootmounter"
REPO_URL="https://raw.githubusercontent.com/albertuszerk/rootmounter/main"

# 3. USB-Autosuspend deaktivieren
sudo mkdir -p /etc/modprobe.d/
echo "options usbcore autosuspend=-1" | sudo tee /etc/modprobe.d/disable-usb-autosuspend.conf > /dev/null

# 4. Software & Desktop-Pfad Fix
sudo apt update
sudo apt install -y curl gpg wget zenity xdg-user-dirs flatpak

# NEU: Flatpak-Berechtigung für den Zugriff auf externe Laufwerke setzen
flatpak override --user --filesystem=host org.cryptomator.Cryptomator 2>/dev/null

sudo mkdir -p -m 755 /usr/share/keyrings
curl -skL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xA684470CACCAF35C" | sed -n '/-----BEGIN PGP PUBLIC KEY BLOCK-----/,/-----END PGP PUBLIC KEY BLOCK-----/p' | gpg --dearmor | sudo tee /usr/share/keyrings/insync-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/insync-archive-keyring.gpg] http://apt.insync.io/ubuntu noble non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list
sudo apt update
sudo apt install -y insync

# 5. Skripte laden
mkdir -p "$BIN_DIR" "$CONFIG_DIR"
curl -sL "$REPO_URL/xrootmounter.sh" -o "$BIN_DIR/xrootmounter"
chmod +x "$BIN_DIR/xrootmounter"

# 6. .ini Format (Deine exakten Vorgaben)
OLD_UUID=$(grep "UUID=" "$CONFIG_DIR/config.ini" 2>/dev/null | cut -d'=' -f2)
cat <<EOF > "$CONFIG_DIR/config.ini"
[Hardware]
UUID=${OLD_UUID:-UNBEKANNT}
MOUNT_POINT=/mnt/m2_root

[StandardFolders]
NAMES=Bilder,Videos,Musik,Dokumente,Vorlagen,Oeffentlich

[Roots]
# Moegliche Farben: blue, green, red, yellow, violet, grey
MAIN_FOLDERS=root:blue,workspace:green

[Subfolders]
root=backup,client,clientpic,clientshare,control,db,document,gallery,project,replicate,shareprg,softinst,softinst-shared,temp,template,web,whitepaper
workspace=user-backup,user-control,user-db,user-document,user-download,user-favorites,user-gallery,user-template,user-web
EOF

# 7. Starter
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
xdg-user-dirs-update --force

# 8. Log oeffnen & App starten
if [[ "$*" == *"--log"* ]]; then
    # Wir oeffnen das Log als normaler User, nicht als root
    nohup xdg-open "$LOGFILE" >/dev/null 2>&1 &
fi

rm -f /tmp/xrootmounter.lock
nohup "$BIN_DIR/xrootmounter" >/dev/null 2>&1 &
