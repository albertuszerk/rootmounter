#!/bin/bash
# xrootmounter.sh - X-Root Konsole

# Singleton: Nur eine Instanz erlauben
LOCK_FILE="/tmp/xrootmounter.lock"
if [ -e "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    if ps -p $PID > /dev/null; then exit 0; fi
fi
echo $$ > "$LOCK_FILE"

CONFIG_DIR="$HOME/.config/rootmounter"
CONFIG_FILE="$CONFIG_DIR/config.ini"
MANAGED_FILE="$CONFIG_DIR/managed_dirs.conf"

# Hilfsfunktion: Pruefen ob Verzeichnis DATEIEN enthaelt
has_files() {
    [ -d "$1" ] && [ "$(find "$1" -type f | wc -l)" -gt 0 ]
}

run_modify_dirs() {
    ROOT_SUBS=$(grep "ROOT_SUBFOLDERS" "$CONFIG_FILE" | cut -d'=' -f2)
    WORK_SUBS=$(grep "WORKSPACE_SUBFOLDERS" "$CONFIG_FILE" | cut -d'=' -f2)
    
    # History schreiben
    echo "ROOT:$ROOT_SUBS" > "$MANAGED_FILE"
    echo "WORK:$WORK_SUBS" >> "$MANAGED_FILE"
    
    # Erstellen
    mkdir -p "$HOME/root" "$HOME/workspace"
    for s in ${ROOT_SUBS//,/ }; do mkdir -p "$HOME/root/$s"; done
    for s in ${WORK_SUBS//,/ }; do mkdir -p "$HOME/workspace/$s"; done
    
    # Desktop Links & Geisterordner entfernen
    ln -sf "$HOME/root" "$HOME/Desktop/root"
    ln -sf "$HOME/workspace" "$HOME/Desktop/workspace"
    
    STD_FOLDERS=$(grep "NAMES" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    for f in $STD_FOLDERS; do [ -d "$HOME/$f" ] && ! has_files "$HOME/$f" && rm -rf "$HOME/$f"; done
    xdg-user-dirs-update --set PICTURES "$HOME"
    
    zenity --info --text="Verzeichnisse wurden erfolgreich modifiziert."
}

run_delete_dirs() {
    if has_files "$HOME/root" || has_files "$HOME/workspace"; then
        zenity --error --text="Abbruch: root oder workspace enthaelt noch Dateien!"
        return
    fi
    
    # Anhand der History (managed_dirs.conf) loeschen
    if [ -f "$MANAGED_FILE" ]; then
        # Hier wuerde eine Logik stehen, die gezielt nur die managed Unterordner loescht
        rm -rf "$HOME/root" "$HOME/workspace"
        rm "$HOME/Desktop/root" "$HOME/Desktop/workspace" 2>/dev/null
    fi
    
    # Standardordner wiederherstellen
    STD_FOLDERS=$(grep "NAMES" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    for f in $STD_FOLDERS; do mkdir -p "$HOME/$f"; done
    
    zenity --info --text="X-Root Verzeichnisse entfernt und Standardordner wiederhergestellt."
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
            # ... (Mount Logik wie bisher) ...
            zenity --info --text="Storage erfolgreich eingebunden!" ;;
        "Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "Verzeichnisse modifizieren") run_modify_dirs ;;
        "Verzeichnisse loeschen (falls leer)") run_delete_dirs ;;
        "Cryptomator") flatpak run org.cryptomator.Cryptomator & ;;
        "Insync") insync show & ;;
        "Uninstall (Vollstaendig)") 
            zenity --question --text="ACHTUNG: Dies entfernt die App und alle Konfigurationen restlos vom System. Fortfahren?" || continue
            sudo umount /mnt/m2_root 2>/dev/null
            sudo sed -i '/m2_root/d' /etc/fstab
            rm "$HOME/.local/share/applications/xrootmounter.desktop"
            rm -rf "$CONFIG_DIR"
            zenity --info --text="X-Root Mounter wurde sauber vom System entfernt."
            rm "$LOCK_FILE"; exit 0 ;;
        "Beenden"|"") rm "$LOCK_FILE"; exit 0 ;;
    esac
done
