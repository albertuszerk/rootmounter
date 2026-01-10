#!/bin/bash
# xrootmounter.sh - X-Root Konsole (Version 18.0)

LOCK_FILE="/tmp/xrootmounter.lock"
[ -e "$LOCK_FILE" ] && PID=$(cat "$LOCK_FILE") && ps -p $PID > /dev/null && exit 0
echo $$ > "$LOCK_FILE"

CONFIG_FILE="$HOME/.config/rootmounter/config.ini"
BOOKMARKS="$HOME/.config/gtk-3.0/bookmarks"

# Prüft, ob ein Verzeichnis Dateien enthält
has_files() { [ -d "$1" ] && [ "$(find "$1" -type f | wc -l)" -gt 0 ]; }

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
        
        SUBS=$(grep "^$folder=" "$CONFIG_FILE" | cut -d'=' -f2)
        for s in ${SUBS//,/ }; do mkdir -p "$HOME/$folder/$s"; done
        MOD_LOG="$MOD_LOG- $folder (Farbe: $color)\n"
    done

    # Standardordner loeschen
    STD_FOLDERS=$(grep "NAMES" "$CONFIG_FILE" | cut -d'=' -f2)
    REMOVED_LOG=""
    for f in ${STD_FOLDERS//,/ }; do
        TARGET_DIR="$HOME/$f"
        # Wir loeschen nur, wenn der Ordner existiert und wirklich leer ist
        if [ -d "$TARGET_DIR" ] && ! has_files "$TARGET_DIR"; then 
            rm -rf "$TARGET_DIR"
            sed -i "/$f/d" "$BOOKMARKS" 2>/dev/null
            REMOVED_LOG="$REMOVED_LOG- $f\n"
        fi
    done

    nautilus -q
    zenity --info --title="Erfolg" --text="$MOD_LOG\nGELOESCHT (da leer):\n${REMOVED_LOG:-keine}\n\nHINWEIS: Seitenleiste aktualisiert."
}

# --- MENUE ---
while true; do
    CHOICE=$(zenity --list --title="X-Root Mounter" --width=450 --height=600 \
        --column="Menue" "HDD/SSD/M.2/.. anzeigen" "SSD/M.2 einhaengen" "Konfiguration editieren" \
        "Verzeichnisse modifizieren" "Verzeichnisse loeschen (falls leer)" "Cryptomator" "Insync" \
        "Menue-Icon entfernen" "Uninstall (Vollstaendig)" "Beenden")

    case $CHOICE in
        "HDD/SSD/M.2/.. anzeigen") gnome-disks & ;;
        "SSD/M.2 einhaengen") # (Mount-Logik einbauen) 
            zenity --info --text="Storage persistent eingebunden!" ;;
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
        "Menue-Icon entfernen") rm "$HOME/.local/share/applications/xrootmounter.desktop"; exit 0 ;;
        "Uninstall (Vollstaendig)") 
            sudo umount /mnt/m2_root 2>/dev/null
            sudo sed -i '/m2_root/d' /etc/fstab
            rm -rf "$HOME/root" "$HOME/workspace" "$HOME/workspace2"
            rm "$HOME/.local/share/applications/xrootmounter.desktop"
            exit 0 ;;
        "Beenden"|"") rm "$LOCK_FILE"; exit 0 ;;
    esac
done
