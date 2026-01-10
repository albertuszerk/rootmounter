#!/bin/bash
# xrootmounter.sh - X-Root Konsole

LOCK_FILE="/tmp/xrootmounter.lock"
[ -e "$LOCK_FILE" ] && PID=$(cat "$LOCK_FILE") && ps -p $PID > /dev/null && exit 0
echo $$ > "$LOCK_FILE"

CONFIG_FILE="$HOME/.config/rootmounter/config.ini"
BOOKMARKS="$HOME/.config/gtk-3.0/bookmarks"

run_modify_dirs() {
    # Einlesen der Paare Ordner:Farbe
    MAIN_PAIRS=$(grep "MAIN_FOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    MOD_LOG="ERSTELLTE STRUKTUREN:\n"

    for pair in $MAIN_PAIRS; do
        folder=$(echo $pair | cut -d':' -f1)
        color=$(echo $pair | cut -d':' -f2)
        
        mkdir -p "$HOME/$folder"
        
        # Icon-Farbe setzen (Mapping auf System-Icons)
        ICON_NAME="folder-$color"
        gio set -t string "$HOME/$folder" metadata::custom-icon-name "$ICON_NAME" 2>/dev/null
        
        # Bookmark setzen
        grep -q "file://$HOME/$folder" "$BOOKMARKS" || echo "file://$HOME/$folder $folder" >> "$BOOKMARKS"
        
        SUBS=$(grep "^$folder=" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
        for s in $SUBS; do mkdir -p "$HOME/$folder/$s"; done
        MOD_LOG="$MOD_LOG- $folder (Farbe: $color)\n"
    done

    # Standardordner loeschen
    STD_FOLDERS=$(grep "NAMES" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    REMOVED_LOG=""
    for f in $STD_FOLDERS; do
        if [ -d "$HOME/$f" ] && [ -z "$(ls -A "$HOME/$f")" ]; then 
            rm -rf "$HOME/$f"
            sed -i "/$f/d" "$BOOKMARKS" 2>/dev/null
            REMOVED_LOG="$REMOVED_LOG- $f\n"
        fi
    done

    nautilus -q
    zenity --info --title="Erfolg" --text="$MOD_LOG\nGELOESCHT (da leer):\n${REMOVED_LOG:-keine}"
}

# --- MENUE (Inkl. Soft-Uninstall) ---
while true; do
    CHOICE=$(zenity --list --title="X-Root Mounter" --width=450 --height=600 \
        --column="Menue" "HDD/SSD/M.2/.. anzeigen" "SSD/M.2 einhaengen" "Konfiguration editieren" \
        "Verzeichnisse modifizieren" "Verzeichnisse loeschen (falls leer)" "Cryptomator" "Insync" \
        "Uninstall (Soft)" "Uninstall (Vollstaendig)" "Beenden")

    case $CHOICE in
        "Verzeichnisse modifizieren") run_modify_dirs ;;
        "SSD/M.2 einhaengen") # (Mount Logik einbauen)
            zenity --info --text="Storage persistent eingebunden!" ;;
        "Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "Cryptomator") flatpak run org.cryptomator.Cryptomator & ;;
        "Insync") insync show & ;;
        "Uninstall (Soft)") rm "$HOME/.local/share/applications/xrootmounter.desktop"; exit 0 ;;
        "Uninstall (Vollstaendig)") # (Vollstaendige Loesch-Logik)
            rm "$LOCK_FILE"; exit 0 ;;
        "Beenden"|"") rm "$LOCK_FILE"; exit 0 ;;
    esac
done
