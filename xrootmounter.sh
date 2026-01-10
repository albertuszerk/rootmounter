#!/bin/bash
# xrootmounter.sh - X-Root Konsole

LOCK_FILE="/tmp/xrootmounter.lock"
[ -e "$LOCK_FILE" ] && PID=$(cat "$LOCK_FILE") && ps -p $PID > /dev/null && exit 0
echo $$ > "$LOCK_FILE"

CONFIG_FILE="$HOME/.config/rootmounter/config.ini"
BOOKMARKS="$HOME/.config/gtk-3.0/bookmarks"

has_files() { [ -d "$1" ] && [ "$(find "$1" -type f | wc -l)" -gt 0 ]; }

run_modify_dirs() {
    PAIRS=$(grep "MAIN_FOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    MOD_LOG="ERSTELLTE STRUKTUREN:\n"
    
    for pair in $PAIRS; do
        if [[ "$pair" == *":"* ]]; then
            folder=$(echo $pair | cut -d':' -f1)
            color=$(echo $pair | cut -d':' -f2)
        else
            folder=$pair
            color="grey"
        fi
        
        mkdir -p "$HOME/$folder"
        gio set -t string "$HOME/$folder" metadata::custom-icon-name "folder-$color" 2>/dev/null
        grep -q "file://$HOME/$folder" "$BOOKMARKS" || echo "file://$HOME/$folder $folder" >> "$BOOKMARKS"
        
        SUBS=$(grep "^$folder=" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
        for s in ${SUBS//,/ }; do mkdir -p "$HOME/$folder/$s"; done
        MOD_LOG="$MOD_LOG- $folder (Farbe: $color)\n"
    done

    STD_FOLDERS=$(grep "NAMES" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    REMOVED_LOG=""
    for f in ${STD_FOLDERS//,/ }; do
        if [ -d "$HOME/$f" ] && ! has_files "$HOME/$f"; then 
            rm -rf "$HOME/$f"
            sed -i "/$f/d" "$BOOKMARKS" 2>/dev/null
            REMOVED_LOG="$REMOVED_LOG- $f\n"
        fi
    done

    nautilus -q
    zenity --info --title="Erfolg" --text="$MOD_LOG\nGELOESCHT (da leer):\n${REMOVED_LOG:-keine}"
}

# --- MENUE ---
while true; do
    CHOICE=$(zenity --list --title="X-Root Mounter" --width=450 --height=600 \
        --column="Menue" "HDD/SSD/M.2/.. anzeigen" "SSD/M.2 einhaengen" "Konfiguration editieren" \
        "Verzeichnisse modifizieren" "Verzeichnisse loeschen (falls leer)" "Cryptomator" "Insync" \
        "Uninstall (Soft)" "Uninstall (Vollstaendig)" "Beenden")

    case $CHOICE in
        "HDD/SSD/M.2/.. anzeigen") gnome-disks & ;;
        "SSD/M.2 einhaengen") # (Mount Logik hier einfügen) 
            zenity --info --text="Storage persistent eingebunden!" ;;
        "Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "Verzeichnisse modifizieren") run_modify_dirs ;;
        "Verzeichnisse loeschen (falls leer)"|"Uninstall (Vollstaendig)") 
            zenity --question --text="Struktur wirklich entfernen?" && rm -rf "$HOME/root" "$HOME/workspace" "$HOME/workspace2"
            [ "$CHOICE" == "Uninstall (Vollstaendig)" ] && { rm "$HOME/.local/share/applications/xrootmounter.desktop"; exit 0; } ;;
        "Cryptomator") flatpak run org.cryptomator.Cryptomator & ;;
        "Insync") insync show & ;;
        "Uninstall (Soft)") rm "$HOME/.local/share/applications/xrootmounter.desktop"; exit 0 ;;
        "Beenden"|"") rm "$LOCK_FILE"; exit 0 ;;
    esac
done
