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

# Sicherheit: Prueft rekursiv, ob der Ordner wirklich leer ist
is_folder_empty() {
    [ -d "$1" ] && [ -z "$(ls -A "$1")" ]
}

run_delete_dirs_safe() {
    MAIN_PAIRS=$(grep "MAIN_FOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    GELOESCHT=""
    GESTOPPT=""

    for pair in $MAIN_PAIRS; do
        folder=${pair%%:*}
        TARGET="$HOME/$folder"
        
        if [ -d "$TARGET" ]; then
            if is_folder_empty "$TARGET"; then
                rm -rf "$TARGET"
                sed -i "\|$folder|d" "$BOOKMARKS" 2>/dev/null
                GELOESCHT="$GELOESCHT- $folder\n"
            else
                GESTOPPT="$GESTOPPT- $folder (enthaelt noch Dateien!)\n"
            fi
        fi
    done

    MSG=""
    [ ! -z "$GELOESCHT" ] && MSG="ERFOLGREICH GELOESCHT:\n$GELOESCHT"
    [ ! -z "$GESTOPPT" ] && MSG="$MSG\nABGEBROCHEN (nicht leer):\n$GESTOPPT"
    
    zenity --info --title="Loesch-Ergebnis" --text="${MSG:-Keine Ordner zum Loeschen gefunden.}"
}

# --- MENUE ---
while true; do
    # Untertitel etwas groesser (medium) und fett
    SUBTITLE="<span size='medium' weight='bold'>In 5 Schritten zum Ziel</span>"
    
    CHOICE=$(zenity --list --title="X-Root Mounter 1.0" --text="$SUBTITLE" --width=500 --height=680 \
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
            if mountpoint -q "$MOUNT_PATH"; then zenity --info --text="SSD ist bereits aktiv."; else
                DEVICES=$(lsblk -p -rn -o NAME,SIZE,TYPE,UUID | awk '$3=="part" {print $1 "|" $2 "|" $4}')
                CHOICE_ROW=$(echo "$DEVICES" | tr '|' '\n' | zenity --list --title="Partition waehlen" --column="Pfad" --column="Groesse" --column="UUID" --width=600 --height=400)
                [ ! -z "$CHOICE_ROW" ] && SEL_UUID=$(echo "$CHOICE_ROW" | awk '{print $NF}') && \
                sed -i "s|^UUID=.*|UUID=$SEL_UUID|" "$CONFIG_FILE" && sudo mkdir -p "$MOUNT_PATH" && \
                sudo mount -a && zenity --info --text="Eingebunden!"
            fi ;;
        "3) Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "4) Verzeichnisse modifizieren") run_modify_dirs ;; # Logik bleibt gleich
        "5) Starter-Icon entfernen") rm "$HOME/.local/share/applications/xrootmounter.desktop"; exit 0 ;;
        "   ") continue ;;
        "Cryptomator starten") flatpak run org.cryptomator.Cryptomator & ;;
        "Insync starten") insync start 2>/dev/null; sleep 1; insync show & ;;
        "Verzeichnisse loeschen (falls leer)") run_delete_dirs_safe ;;
        "Uninstall (Vollstaendig)") run_uninstall_full ;; # Logik bleibt gleich
        "Beenden"|"") rm "$LOCK_FILE"; exit 0 ;;
    esac
done
