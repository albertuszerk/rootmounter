#!/bin/bash
# xrootmounter.sh - X-Root Konsole

LOCK_FILE="/tmp/xrootmounter.lock"
[ -e "$LOCK_FILE" ] && PID=$(cat "$LOCK_FILE") && ps -p $PID > /dev/null && exit 0
echo $$ > "$LOCK_FILE"

CONFIG_DIR="$HOME/.config/rootmounter"
CONFIG_FILE="$CONFIG_DIR/config.ini"
BOOKMARKS="$HOME/.config/gtk-3.0/bookmarks"

has_files() { [ -d "$1" ] && [ "$(find "$1" -type f | wc -l)" -gt 0 ]; }

run_ssd_mount() {
    # Wir muessen die Liste tatsaechlich anzeigen
    DEVICES=$(lsblk -p -rn -o NAME,SIZE,TYPE,UUID | awk '$3=="part" {print $1 "|" $2 "|" $4}')
    [ -z "$DEVICES" ] && { zenity --error --text="Keine Partitionen gefunden!"; return; }

    CHOICE_ROW=$(echo "$DEVICES" | tr '|' '\n' | zenity --list --title="Partition waehlen" --column="Pfad" --column="Groesse" --column="UUID" --width=600 --height=400)
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
    MAIN_FOLDERS=$(grep "MAIN_FOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    MOD_LOG="ERSTELLTE STRUKTUREN:\n"
    
    # Icons Definition (Vorgabe)
    # root = Blau, workspace = Gruen, workspace2 = Lila
    declare -A ICONS=( ["root"]="folder-blue" ["workspace"]="folder-green" ["workspace2"]="folder-violet" )

    for folder in $MAIN_FOLDERS; do
        mkdir -p "$HOME/$folder"
        # Icon setzen
        ICON_NAME=${ICONS[$folder]:-"folder-remote"}
        gio set -t string "$HOME/$folder" metadata::custom-icon-name "$ICON_NAME" 2>/dev/null
        
        # In Seitenleiste (Bookmarks) pruefen/fuegen
        grep -q "file://$HOME/$folder" "$BOOKMARKS" || echo "file://$HOME/$folder $folder" >> "$BOOKMARKS"
        
        SUBS=$(grep "^$folder=" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
        for s in $SUBS; do mkdir -p "$HOME/$folder/$s"; done
        MOD_LOG="$MOD_LOG- $folder (Icon: $ICON_NAME)\n"
    done

    # Standardordner bereinigen & Log erweitern
    STD_FOLDERS=$(grep "NAMES" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    REMOVED_LOG=""
    for f in $STD_FOLDERS; do
        if [ -d "$HOME/$f" ] && ! has_files "$HOME/$f"; then 
            rm -rf "$HOME/$f"
            sed -i "/$f/d" "$BOOKMARKS" 2>/dev/null
            REMOVED_LOG="$REMOVED_LOG- $f\n"
        fi
    done
    
    # Desktop-Fix: Standardpfade zurueck auf Home, damit sie nicht auf dem Desktop erscheinen
    xdg-user-dirs-update --set PICTURES "$HOME"
    xdg-user-dirs-update --set VIDEOS "$HOME"
    xdg-user-dirs-update --set MUSIC "$HOME"
    xdg-user-dirs-update --set DOCUMENTS "$HOME"

    nautilus -q
    zenity --info --title="Modifizierung erfolgreich" --text="$MOD_LOG\nGELOESCHT (da leer):\n${REMOVED_LOG:-keine}\n\nHinweis: Seitenleiste aktualisiert."
}

run_uninstall_full() {
    zenity --question --text="ACHTUNG: Dies entfernt root/workspace/workspace2, alle Subfolder und setzt alle Standardpfade zurueck. Fortfahren?" || return
    sudo umount /mnt/m2_root 2>/dev/null
    sudo sed -i '/m2_root/d' /etc/fstab
    
    MAIN_FOLDERS=$(grep "MAIN_FOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    for folder in $MAIN_FOLDERS; do 
        rm -rf "$HOME/$folder"
        sed -i "/$folder/d" "$BOOKMARKS" 2>/dev/null
    done
    
    STD_FOLDERS=$(grep "NAMES" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    for f in $STD_FOLDERS; do mkdir -p "$HOME/$f"; done
    
    rm "$HOME/.local/share/applications/xrootmounter.desktop"
    rm "$LOCK_FILE"; zenity --info --text="X-Root Mounter wurde sauber entfernt."; exit 0
}

# --- MENUE ---
while true; do
    CHOICE=$(zenity --list --title="X-Root Mounter" --width=450 --height=600 \
        --column="Menue" "HDD/SSD/M.2/.. anzeigen" "SSD/M.2 einhaengen" "Konfiguration editieren" \
        "Verzeichnisse modifizieren" "Verzeichnisse loeschen (falls leer)" "Cryptomator" "Insync" \
        "Uninstall (Soft)" "Uninstall (Vollstaendig)" "Beenden")

    case $CHOICE in
        "HDD/SSD/M.2/.. anzeigen") gnome-disks & ;;
        "SSD/M.2 einhaengen") run_ssd_mount ;;
        "Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "Verzeichnisse modifizieren") run_modify_dirs ;;
        "Verzeichnisse loeschen (falls leer)") run_uninstall_full ;;
        "Cryptomator") flatpak run org.cryptomator.Cryptomator & ;;
        "Insync") insync show & ;;
        "Uninstall (Soft)") rm "$HOME/.local/share/applications/xrootmounter.desktop"; rm "$LOCK_FILE"; exit 0 ;;
        "Uninstall (Vollstaendig)") run_uninstall_full ;;
        "Beenden"|"") rm "$LOCK_FILE"; exit 0 ;;
    esac
done
