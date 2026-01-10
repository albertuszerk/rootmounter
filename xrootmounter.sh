#!/bin/bash
# xrootmounter.sh - X-Root Konsole (Version 17.0)

LOCK_FILE="/tmp/xrootmounter.lock"
[ -e "$LOCK_FILE" ] && PID=$(cat "$LOCK_FILE") && ps -p $PID > /dev/null && exit 0
echo $$ > "$LOCK_FILE"

CONFIG_FILE="$HOME/.config/rootmounter/config.ini"
BOOKMARKS="$HOME/.config/gtk-3.0/bookmarks"

# Prüft, ob ein Verzeichnis wirklich Dateien enthält
has_files() { [ -d "$1" ] && [ "$(find "$1" -type f | wc -l)" -gt 0 ]; }

run_ssd_mount() {
    DEVICES=$(lsblk -p -rn -o NAME,SIZE,TYPE,UUID | awk '$3=="part" {print $1 "|" $2 "|" $4}')
    [ -z "$DEVICES" ] && { zenity --error --text="Keine Partitionen gefunden!"; return; }

    CHOICE_ROW=$(echo "$DEVICES" | tr '|' '\n' | zenity --list --title="Partition waehlen" --column="Pfad" --column="Groesse" --column="UUID" --width=600 --height=400)
    
    [ -z "$CHOICE_ROW" ] && return
    SEL_UUID=$(echo "$CHOICE_ROW" | awk '{print $NF}')
    [ -z "$SEL_UUID" ] && return
    
    sed -i "s|^UUID=.*|UUID=$SEL_UUID|" "$CONFIG_FILE"
    sudo mkdir -p /mnt/m2_root
    FSTAB_LINE="UUID=$SEL_UUID /mnt/m2_root ntfs-3g defaults,uid=$(id -u),gid=$(id -g),umask=007 0 2"
    grep -q "$SEL_UUID" /etc/fstab || echo "$FSTAB_LINE" | sudo tee -a /etc/fstab
    sudo mount -a
    zenity --info --text="Storage wurde dauerhaft (persistent) eingebunden!"
}

run_modify_dirs() {
    PAIRS=$(grep "MAIN_FOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    MOD_LOG="ERSTELLTE STRUKTUREN:\n"
    
    for pair in $PAIRS; do
        folder=${pair%%:*}
        color=${pair##*:}
        [ "$folder" == "$color" ] && color="grey"

        mkdir -p "$HOME/$folder"
        gio set -t string "$HOME/$folder" metadata::custom-icon-name "folder-$color" 2>/dev/null
        grep -q "file://$HOME/$folder" "$BOOKMARKS" || echo "file://$HOME/$folder $folder" >> "$BOOKMARKS"
        
        # Subfolder aus .ini lesen
        SUBS=$(grep "^$folder=" "$CONFIG_FILE" | cut -d'=' -f2)
        for s in ${SUBS//,/ }; do mkdir -p "$HOME/$folder/$s"; done
        MOD_LOG="$MOD_LOG- $folder (Farbe: $color)\n"
    done

    # Standardordner loeschen
    STD_FOLDERS=$(grep "NAMES" "$CONFIG_FILE" | cut -d'=' -f2)
    REMOVED_LOG=""
    for f in ${STD_FOLDERS//,/ }; do
        TARGET_DIR="$HOME/$f"
        if [ -d "$TARGET_DIR" ] && ! has_files "$TARGET_DIR"; then 
            rm -rf "$TARGET_DIR"
            sed -i "/$f/d" "$BOOKMARKS" 2>/dev/null
            REMOVED_LOG="$REMOVED_LOG- $f\n"
        fi
    done

    nautilus -q
    zenity --info --title="Erfolg" --text="$MOD_LOG\nGELOESCHT (da leer):\n${REMOVED_LOG:-keine}\n\nHINWEIS: Seitenleiste aktualisiert und Geisterordner entfernt."
}

run_uninstall_full() {
    WARN_TEXT="ACHTUNG: Dies entfernt root/workspace, den Starter und setzt alle Pfade zurueck. Fortfahren?"
    zenity --question --title="Vollstaendiger Uninstall" --text="$WARN_TEXT" || return
    
    sudo umount /mnt/m2_root 2>/dev/null
    sudo sed -i '/m2_root/d' /etc/fstab
    
    # Root Verzeichnisse loeschen
    MAIN_PAIRS=$(grep "MAIN_FOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    for pair in $MAIN_PAIRS; do
        f=${pair%%:*}
        rm -rf "$HOME/$f"
        sed -i "/$f/d" "$BOOKMARKS" 2>/dev/null
    done
    
    # Standardordner wiederherstellen
    STD_FOLDERS=$(grep "NAMES" "$CONFIG_FILE" | cut -d'=' -f2)
    for f in ${STD_FOLDERS//,/ }; do mkdir -p "$HOME/$f"; done
    
    rm "$HOME/.local/share/applications/xrootmounter.desktop"
    rm "$LOCK_FILE"
    zenity --info --text="X-Root Mounter wurde sauber entfernt."
    exit 0
}

# --- MENUE ---
while true; do
    CHOICE=$(zenity --list --title="X-Root Mounter" --width=450 --height=600 \
        --column="Menue" "HDD/SSD/M.2/.. anzeigen" "SSD/M.2 einhaengen" "Konfiguration editieren" \
        "Verzeichnisse modifizieren" "Verzeichnisse loeschen (falls leer)" "Cryptomator" "Insync" \
        "Starter-Icon entfernen" "Uninstall (Vollstaendig)" "Beenden")

    case $CHOICE in
        "HDD/SSD/M.2/.. anzeigen") gnome-disks & ;;
        "SSD/M.2 einhaengen") run_ssd_mount ;;
        "Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "Verzeichnisse modifizieren") run_modify_dirs ;;
        "Verzeichnisse loeschen (falls leer)") 
            if has_files "$HOME/root" || has_files "$HOME/workspace"; then
                zenity --error --text="Abbruch: Ordner enthalten noch Dateien!"
            else
                rm -rf "$HOME/root" "$HOME/workspace" "$HOME/workspace2"
                zenity --info --text="Strukturen entfernt."
            fi ;;
        "Cryptomator") flatpak run org.cryptomator.Cryptomator & ;;
        "Insync") insync show & ;;
        "Starter-Icon entfernen") rm "$HOME/.local/share/applications/xrootmounter.desktop"; exit 0 ;;
        "Uninstall (Vollstaendig)") run_uninstall_full ;;
        "Beenden"|"") rm "$LOCK_FILE"; exit 0 ;;
    esac
done
