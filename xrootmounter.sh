#!/bin/bash
# xrootmounter.sh - X-Root Konsole

LOCK_FILE="/tmp/xrootmounter.lock"
[ -e "$LOCK_FILE" ] && PID=$(cat "$LOCK_FILE") && ps -p $PID > /dev/null && exit 0
echo $$ > "$LOCK_FILE"

CONFIG_FILE="$HOME/.config/rootmounter/config.ini"
BOOKMARKS="$HOME/.config/gtk-3.0/bookmarks"
MOUNT_PATH="/mnt/m2_root"

has_files() { [ -d "$1" ] && [ "$(find "$1" -type f | wc -l)" -gt 0 ]; }

run_ssd_mount() {
    # Sicherheitsabfrage vor dem Einhaengen
    if mountpoint -q "$MOUNT_PATH"; then
        zenity --info --title="Information" --text="Der Storage ist bereits unter $MOUNT_PATH eingebunden."
        return
    fi

    DEVICES=$(lsblk -p -rn -o NAME,SIZE,TYPE,UUID | awk '$3=="part" {print $1 "|" $2 "|" $4}')
    CHOICE_ROW=$(echo "$DEVICES" | tr '|' '\n' | zenity --list --title="Partition waehlen" --column="Pfad" --column="Groesse" --column="UUID" --width=600 --height=400)
    
    [ -z "$CHOICE_ROW" ] && return
    SEL_UUID=$(echo "$CHOICE_ROW" | awk '{print $NF}')
    
    sed -i "s|^UUID=.*|UUID=$SEL_UUID|" "$CONFIG_FILE"
    sudo mkdir -p "$MOUNT_PATH"
    FSTAB_LINE="UUID=$SEL_UUID $MOUNT_PATH ntfs-3g defaults,uid=$(id -u),gid=$(id -g),umask=007 0 2"
    grep -q "$SEL_UUID" /etc/fstab || echo "$FSTAB_LINE" | sudo tee -a /etc/fstab
    sudo mount -a
    zenity --info --text="Storage wurde dauerhaft (persistent) eingebunden!"
}

run_uninstall_full() {
    zenity --question --title="Vollstaendiger Uninstall" --text="Wollen Sie X-Root wirklich restlos entfernen? Alle Standardordner werden wiederhergestellt." || return
    sudo umount "$MOUNT_PATH" 2>/dev/null
    sudo sed -i "\|$MOUNT_PATH|d" /etc/fstab
    sudo rm -f /etc/modprobe.d/disable-usb-autosuspend.conf
    
    # Root Ordner loeschen
    rm -rf "$HOME/root" "$HOME/workspace" "$HOME/workspace2"
    
    # Standardordner physisch wiederherstellen & Pfade resetten
    mkdir -p "$HOME"/{Bilder,Videos,Musik,Dokumente,Vorlagen,Oeffentlich}
    
    cat <<EOF > "$HOME/.config/user-dirs.dirs"
XDG_DESKTOP_DIR="\$HOME/Schreibtisch"
XDG_DOWNLOAD_DIR="\$HOME/Downloads"
XDG_TEMPLATES_DIR="\$HOME/Vorlagen"
XDG_PUBLICSHARE_DIR="\$HOME/Oeffentlich"
XDG_DOCUMENTS_DIR="\$HOME/Dokumente"
XDG_MUSIC_DIR="\$HOME/Musik"
XDG_PICTURES_DIR="\$HOME/Bilder"
XDG_VIDEOS_DIR="\$HOME/Videos"
EOF
    
    rm "$HOME/.local/share/applications/xrootmounter.desktop"
    xdg-user-dirs-update --force
    zenity --info --text="Deinstallation abgeschlossen. Alle Standardordner wurden wiederhergestellt."
    rm "$LOCK_FILE"; exit 0
}

# --- MENUE ---
while true; do
    CHOICE=$(zenity --list --title="X-Root Mounter" --width=450 --height=600 \
        --column="Menue" \
        "1) HDD/SSD/M.2/.. anzeigen" \
        "2) SSD/M.2 einhaengen" \
        "3) Konfiguration editieren" \
        "4) Verzeichnisse modifizieren" \
        "5) Verzeichnisse loeschen (falls leer)" \
        "6) Starter-Icon entfernen" \
        "--------------" \
        "Cryptomator" \
        "Insync" \
        "Uninstall (Vollstaendig)" \
        "Beenden")

    case $CHOICE in
        "1) HDD/SSD/M.2/.. anzeigen") gnome-disks & ;;
        "2) SSD/M.2 einhaengen") run_ssd_mount ;;
        "3) Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "4) Verzeichnisse modifizieren") run_modify_dirs ;;
        "5) Verzeichnisse loeschen (falls leer)") rm -rf "$HOME/root" "$HOME/workspace" "$HOME/workspace2"; zenity --info --text="Ordner entfernt." ;;
        "6) Starter-Icon entfernen") rm "$HOME/.local/share/applications/xrootmounter.desktop"; exit 0 ;;
        "--------------") continue ;;
        "Cryptomator") flatpak run org.cryptomator.Cryptomator & ;;
        "Insync") insync show & ;;
        "Uninstall (Vollstaendig)") run_uninstall_full ;;
        "Beenden"|"") rm "$LOCK_FILE"; exit 0 ;;
    esac
done
