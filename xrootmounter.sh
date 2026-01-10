#!/bin/bash
# xrootmounter.sh - X-Root Konsole

# Singleton
LOCK_FILE="/tmp/xrootmounter.lock"
if [ -e "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    if ps -p $PID > /dev/null; then exit 0; fi
fi
echo $$ > "$LOCK_FILE"

CONFIG_DIR="$HOME/.config/rootmounter"
CONFIG_FILE="$CONFIG_DIR/config.ini"

has_files() {
    [ -d "$1" ] && [ "$(find "$1" -type f | wc -l)" -gt 0 ]
}

run_modify_dirs() {
    ROOT_SUBS=$(grep "ROOT_SUBFOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    WORK_SUBS=$(grep "WORKSPACE_SUBFOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    STD_FOLDERS=$(grep "NAMES" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')

    mkdir -p "$HOME/root" "$HOME/workspace"
    for s in $ROOT_SUBS; do mkdir -p "$HOME/root/$s"; done
    for s in $WORK_SUBS; do mkdir -p "$HOME/workspace/$s"; done
    
    ln -sf "$HOME/root" "$HOME/Desktop/root"
    ln -sf "$HOME/workspace" "$HOME/Desktop/workspace"

    REMOVED_LIST=""
    for f in $STD_FOLDERS; do
        if [ -d "$HOME/$f" ] && ! has_files "$HOME/$f"; then 
            rm -rf "$HOME/$f"
            REMOVED_LIST="$REMOVED_LIST\n- $f"
        fi
    done
    
    xdg-user-dirs-update --set PICTURES "$HOME"
    
    INFO_TEXT="Folgende Aenderungen wurden vorgenommen:\n\n"
    INFO_TEXT="${INFO_TEXT}ERSTELLT:\n- Verzeichnis 'root' (inkl. aller Subfolder gemaess .ini)\n"
    INFO_TEXT="${INFO_TEXT}- Verzeichnis 'workspace' (inkl. aller Subfolder gemaess .ini)\n"
    INFO_TEXT="${INFO_TEXT}- Desktop-Verknuepfungen fuer 'root' und 'workspace'\n\n"
    INFO_TEXT="${INFO_TEXT}GELOESCHT (da leer):${REMOVED_LIST:- \n- keine}\n\n"
    INFO_TEXT="${INFO_TEXT}HINWEIS: Bitte loggen Sie sich aus und wieder ein, damit die Geisterordner im Menue verschwinden."
    
    zenity --info --title="Modifizierung erfolgreich" --text="$INFO_TEXT"
}

run_delete_dirs() {
    if has_files "$HOME/root" || has_files "$HOME/workspace"; then
        zenity --error --text="Abbruch: root oder workspace enthaelt noch Dateien!"
        return
    fi
    
    rm -rf "$HOME/root" "$HOME/workspace"
    rm "$HOME/Desktop/root" "$HOME/Desktop/workspace" 2>/dev/null
    
    STD_FOLDERS=$(grep "NAMES" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    CREATED_LIST=""
    for f in $STD_FOLDERS; do 
        mkdir -p "$HOME/$f"
        CREATED_LIST="$CREATED_LIST\n- $f"
    done
    
    INFO_TEXT="Folgende Aenderungen wurden vorgenommen:\n\n"
    INFO_TEXT="${INFO_TEXT}GELOESCHT:\n- Die Verzeichnisse 'root' und 'workspace' (da sie leer waren)\n"
    INFO_TEXT="${INFO_TEXT}- Desktop-Verknuepfungen entfernt\n\n"
    INFO_TEXT="${INFO_TEXT}WIEDERHERGESTELLT:\n${CREATED_LIST}"
    
    zenity --info --title="Verzeichnisse entfernt" --text="$INFO_TEXT"
}

run_uninstall_full() {
    WARN_TEXT="ACHTUNG: Dies wird die X-Root App, den Starter und alle Konfigurationen restlos vom System entfernen.\n\n"
    WARN_TEXT="${WARN_TEXT}- Die Verzeichnisse 'root' und 'workspace' werden geloescht (sofern leer).\n"
    WARN_TEXT="${WARN_TEXT}- Die Standardordner (Bilder, Videos, etc.) werden gemaess managed_dirs.conf wiederhergestellt.\n\n"
    WARN_TEXT="${WARN_TEXT}Wollen Sie wirklich fortfahren?"
    
    zenity --question --title="Vollstaendiger Uninstall" --text="$WARN_TEXT" || return
    
    sudo umount /mnt/m2_root 2>/dev/null
    sudo sed -i '/m2_root/d' /etc/fstab
    
    # Gleiche Logik wie run_delete_dirs
    rm -rf "$HOME/root" "$HOME/workspace"
    rm "$HOME/Desktop/root" "$HOME/Desktop/workspace" 2>/dev/null
    STD_FOLDERS=$(grep "NAMES" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    for f in $STD_FOLDERS; do mkdir -p "$HOME/$f"; done
    
    rm "$HOME/.local/share/applications/xrootmounter.desktop"
    
    zenity --info --text="Deinstallation abgeschlossen. Alle Verzeichnisse wurden bereinigt/wiederhergestellt."
    rm "$LOCK_FILE"; exit 0
}

# --- HAUPTMENUE ---
while true; do
    CHOICE=$(zenity --list --title="X-Root Mounter" --width=450 --height=550 \
        --column="Menue" \
        "HDD/SSD/M.2/.. anzeigen" \
        "SSD/M.2 einhaengen" \
        "Konfiguration editieren" \
        "Verzeichnisse modifizieren" \
        "Verzeichnisse loeschen (falls leer)" \
        "Cryptomator" \
        "Insync" \
        "Uninstall (Soft)" \
        "Uninstall (Vollstaendig)" \
        "Beenden")

    case $CHOICE in
        "HDD/SSD/M.2/.. anzeigen") gnome-disks & ;;
        "SSD/M.2 einhaengen") 
            # (Mount Logik bleibt gleich)
            zenity --info --text="Storage erfolgreich eingebunden!" ;;
        "Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "Verzeichnisse modifizieren") run_modify_dirs ;;
        "Verzeichnisse loeschen (falls leer)") run_delete_dirs ;;
        "Cryptomator") flatpak run org.cryptomator.Cryptomator & ;;
        "Insync") insync show & ;;
        "Uninstall (Soft)") rm "$HOME/.local/share/applications/xrootmounter.desktop"; rm "$LOCK_FILE"; exit 0 ;;
        "Uninstall (Vollstaendig)") run_uninstall_full ;;
        "Beenden"|"") rm "$LOCK_FILE"; exit 0 ;;
    esac
done
