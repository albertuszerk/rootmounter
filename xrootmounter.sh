#!/bin/bash
# xrootmounter.sh - X-Root Konsole (Version 20.0)

LOCK_FILE="/tmp/xrootmounter.lock"
[ -e "$LOCK_FILE" ] && PID=$(cat "$LOCK_FILE") && ps -p $PID > /dev/null && exit 0
echo $$ > "$LOCK_FILE"

CONFIG_FILE="$HOME/.config/rootmounter/config.ini"
BOOKMARKS="$HOME/.config/gtk-3.0/bookmarks"

has_files() { [ -d "$1" ] && [ "$(find "$1" -type f | wc -l)" -gt 0 ]; }

run_ssd_mount() {
    # Partitionswahl erzwingen
    DEVICES=$(lsblk -p -rn -o NAME,SIZE,TYPE,UUID | awk '$3=="part" {print $1 "|" $2 "|" $4}')
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
        "Menue-Icon entfernen" "Uninstall (Vollstaendig)" "Beenden")

    case $CHOICE in
        "HDD/SSD/M.2/.. anzeigen") gnome-disks & ;;
        "SSD/M.2 einhaengen") run_ssd_mount ;;
        "Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "Verzeichnisse modifizieren") run_modify_dirs ;;
        "Verzeichnisse loeschen (falls leer)") 
            zenity --question --text="Strukturen root/workspace/workspace2 wirklich entfernen?" && rm -rf "$HOME/root" "$HOME/workspace" "$HOME/workspace2" ;;
        "Cryptomator") flatpak run org.cryptomator.Cryptomator & ;;
        "Insync") insync show & ;;
        "Menue-Icon entfernen") rm "$HOME/.local/share/applications/xrootmounter.desktop"; exit 0 ;;
        "Uninstall (Vollstaendig)") 
            zenity --question --title="Vollstaendiger Uninstall" --text="Wollen Sie wirklich alles restlos entfernen?" && {
                sudo umount /mnt/m2_root 2>/dev/null
                sudo sed -i '/m2_root/d' /etc/fstab
                rm -rf "$HOME/root" "$HOME/workspace" "$HOME/workspace2"
                rm "$HOME/.local/share/applications/xrootmounter.desktop"
                exit 0
            } ;;
        "Beenden"|"") rm "$LOCK_FILE"; exit 0 ;;
    esac
done
