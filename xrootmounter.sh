#!/bin/bash
# xrootmounter.sh - X-Root Konsole v1.0

LOCK_FILE="/tmp/xrootmounter.lock"
if [ -e "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    ps -p $PID > /dev/null && exit 0
    rm "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"

CONFIG_FILE="$HOME/.config/rootmounter/config.ini"
BOOKMARKS="$HOME/.config/gtk-3.0/bookmarks"
MOUNT_PATH="/mnt/m2_root"

# Prüft rekursiv, ob der Ordner wirklich leer ist (inkl. versteckter Dateien)
is_folder_empty() {
    [ -d "$1" ] && [ -z "$(ls -A "$1")" ]
}

run_modify_dirs() {
    # 1. Hauptordner aus INI lesen
    MAIN_PAIRS=$(grep "MAIN_FOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    MOD_LOG="ERSTELLTE STRUKTUREN:\n"
    
    for pair in $MAIN_PAIRS; do
        folder=${pair%%:*}
        color=${pair##*:}
        [ "$folder" == "$color" ] && color="grey"

        mkdir -p "$HOME/$folder"
        gio set -t string "$HOME/$folder" metadata::custom-icon-name "folder-$color" 2>/dev/null
        grep -q "file://$HOME/$folder" "$BOOKMARKS" || echo "file://$HOME/$folder $folder" >> "$BOOKMARKS"
        
        # 2. Subfolder fuer diesen Root lesen und via IFS splitten
        SUBS_RAW=$(grep "^$folder=" "$CONFIG_FILE" | cut -d'=' -f2)
        IFS=',' read -ra ADDR <<< "$SUBS_RAW"
        for s in "${ADDR[@]}"; do
            mkdir -p "$HOME/$folder/$s"
        done
        MOD_LOG="$MOD_LOG- $folder (Farbe: $color)\n"
    done

    # 3. Standardordner bereinigen
    STD_FOLDERS_RAW=$(grep "NAMES" "$CONFIG_FILE" | cut -d'=' -f2)
    IFS=',' read -ra STD_ADDR <<< "$STD_FOLDERS_RAW"
    REMOVED_LOG=""
    for f in "${STD_ADDR[@]}"; do
        if [ -d "$HOME/$f" ] && is_folder_empty "$HOME/$f"; then
            rm -rf "$HOME/$f"
            sed -i "\|$f|d" "$BOOKMARKS" 2>/dev/null
            REMOVED_LOG="$REMOVED_LOG- $f\n"
        fi
    done
    
    nautilus -q
    zenity --info --title="Verzeichnisse modifiziert" --text="$MOD_LOG\nGELOESCHT (da leer):\n${REMOVED_LOG:-keine}"
}

run_uninstall_full() {
    zenity --question --title="Vollstaendiger Uninstall" --text="Wollen Sie wirklich alles entfernen? Die Standardordner werden wiederhergestellt." || return
    sudo umount "$MOUNT_PATH" 2>/dev/null
    sudo sed -i "\|$MOUNT_PATH|d" /etc/fstab
    sudo rm -f /etc/modprobe.d/disable-usb-autosuspend.conf
    
    # Root Ordner loeschen
    rm -rf "$HOME/root" "$HOME/workspace"
    
    # Standardordner physisch wiederherstellen
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
    zenity --info --text="System wurde erfolgreich in den Originalzustand versetzt."
    rm "$LOCK_FILE"; exit 0
}

# --- MENUE ---
while true; do
    SUBTITLE="<span size='large' weight='bold'>In 5 Schritten zum Ziel</span>"
    
    CHOICE=$(zenity --list --title="X-Root Mounter 1.0" --text="$SUBTITLE" --width=500 --height=700 \
        --column="Menue-Eintraege" \
        "1) HDD/SSD/M.2/.. anzeigen" \
        "2) SSD/M.2 einhaengen" \
        "3) Konfiguration editieren" \
        "4) Verzeichnisse modifizieren" \
        "5) Starter-Icon entfernen" \
        "   " \
        "Cryptomator starten" \
        "Insync starten" \
        "   " \
        "Verzeichnisse loeschen (falls leer)" \
        "Uninstall (Vollstaendig)" \
        "Beenden")

    case $CHOICE in
        "1) HDD/SSD/M.2/.. anzeigen") gnome-disks & ;;
        "2) SSD/M.2 einhaengen") 
            if mountpoint -q "$MOUNT_PATH"; then zenity --info --text="SSD bereits aktiv."; else
                DEVICES=$(lsblk -p -rn -o NAME,SIZE,TYPE,UUID | awk '$3=="part" {print $1 "|" $2 "|" $4}')
                CHOICE_ROW=$(echo "$DEVICES" | tr '|' '\n' | zenity --list --title="Partition waehlen" --column="Pfad" --column="Groesse" --column="UUID" --width=600 --height=400)
                [ ! -z "$CHOICE_ROW" ] && SEL_UUID=$(echo "$CHOICE_ROW" | awk '{print $NF}') && \
                sed -i "s|^UUID=.*|UUID=$SEL_UUID|" "$CONFIG_FILE" && sudo mkdir -p "$MOUNT_PATH" && \
                sudo mount -a && zenity --info --text="Erfolgreich eingebunden!"
            fi ;;
        "3) Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "4) Verzeichnisse modifizieren") run_modify_dirs ;;
        "5) Starter-Icon entfernen") rm "$HOME/.local/share/applications/xrootmounter.desktop"; exit 0 ;;
        "   ") continue ;;
        "Cryptomator starten") flatpak run org.cryptomator.Cryptomator & ;;
        "Insync starten") insync start 2>/dev/null; sleep 1; insync show & ;;
        "Verzeichnisse loeschen (falls leer)") 
            if ! is_folder_empty "$HOME/root" || ! is_folder_empty "$HOME/workspace"; then
                zenity --error --text="Abbruch: Einer der Ordner enthaelt noch Dateien!"
            else
                rm -rf "$HOME/root" "$HOME/workspace"
                zenity --info --text="Leere Strukturen wurden entfernt."
            fi ;;
        "Uninstall (Vollstaendig)") run_uninstall_full ;;
        "Beenden"|"") rm "$LOCK_FILE"; exit 0 ;;
    esac
done
