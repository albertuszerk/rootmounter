#!/bin/bash
# xrootmounter.sh - X-Root Konsole (Keine Umlaute)

# Singleton
LOCK_FILE="/tmp/xrootmounter.lock"
if [ -e "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    if ps -p $PID > /dev/null; then exit 0; fi
fi
echo $$ > "$LOCK_FILE"

CONFIG_DIR="$HOME/.config/rootmounter"
CONFIG_FILE="$CONFIG_DIR/config.ini"
BOOKMARKS="$HOME/.config/gtk-3.0/bookmarks"

has_files() {
    [ -d "$1" ] && [ "$(find "$1" -type f | wc -l)" -gt 0 ]
}

run_ssd_mount() {
    DEVICES=$(lsblk -p -rn -o NAME,SIZE,TYPE,UUID | awk '$3=="part" {print $1 "|" $2 "|" $4}')
    
    if [ -z "$DEVICES" ]; then
        zenity --error --text="Keine Partitionen gefunden!"
        return
    fi

    CHOICE_ROW=$(echo "$DEVICES" | tr '|' '\n' | zenity --list --title="X-Root: Partition waehlen" \
        --column="Pfad" --column="Groesse" --column="UUID" --width=600 --height=400)
    
    SEL_UUID=$(echo "$CHOICE_ROW" | awk '{print $NF}')
    [ -z "$SEL_UUID" ] && return
    
    sed -i "s|^UUID=.*|UUID=$SEL_UUID|" "$CONFIG_FILE"
    sudo mkdir -p /mnt/m2_root
    FSTAB_LINE="UUID=$SEL_UUID /mnt/m2_root ntfs-3g defaults,uid=$(id -u),gid=$(id -g),umask=007 0 2"
    if ! grep -q "$SEL_UUID" /etc/fstab; then echo "$FSTAB_LINE" | sudo tee -a /etc/fstab; fi
    sudo mount -a
    zenity --info --text="Storage wurde dauerhaft (persistent) eingebunden!"
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
            sed -i "/$f/d" "$BOOKMARKS" 2>/dev/null
        fi
    done
    
    xdg-user-dirs-update --set PICTURES "$HOME"
    
    INFO_TEXT="Folgende Aenderungen wurden vorgenommen:\n\n"
    INFO_TEXT="${INFO_TEXT}ERSTELLT:\n- Verzeichnis 'root' (inkl. Subfolder laut .ini)\n"
    INFO_TEXT="${INFO_TEXT}- Verzeichnis 'workspace' (inkl. Subfolder laut .ini)\n"
    INFO_TEXT="${INFO_TEXT}- Desktop-Links (Schreibtisch)\n\n"
    INFO_TEXT="${INFO_TEXT}GELOESCHT (da leer):${REMOVED_LIST:- \n- keine}\n\n"
    INFO_TEXT="${INFO_TEXT}HINWEIS: Bitte loggen Sie sich aus/ein, um Geisterordner zu entfernen."
    
    zenity --info --title="Modifizierung erfolgreich" --text="$INFO_TEXT"
}

run_uninstall_full() {
    WARN_TEXT="ACHTUNG: Dies wird die X-Root App, den Starter und alle Konfigurationen restlos entfernen.\n\n"
    WARN_TEXT="${WARN_TEXT}- root und workspace werden geloescht (wenn leer).\n"
    WARN_TEXT="${WARN_TEXT}- Standardordner (Bilder, Videos, etc.) werden wiederhergestellt.\n"
    WARN_TEXT="${WARN_TEXT}- Persistenter Mount in fstab wird entfernt.\n\n"
    WARN_TEXT="${WARN_TEXT}Wollen Sie wirklich fortfahren?"
    
    zenity --question --title="Vollstaendiger Uninstall" --text="$WARN_TEXT" || return
    
    sudo umount /mnt/m2_root 2>/dev/null
    sudo sed -i '/m2_root/d' /etc/fstab
    
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
        "Uninstall (Vollstaendig)" \
        "Beenden")

    case $CHOICE in
        "HDD/SSD/M.2/.. anzeigen") gnome-disks & ;;
        "SSD/M.2 einhaengen") run_ssd_mount ;;
        "Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "Verzeichnisse modifizieren") run_modify_dirs ;;
        "Verzeichnisse loeschen (falls leer)") 
            if has_files "$HOME/root" || has_files "$HOME/workspace"; then
                zenity --error --text="Abbruch: root oder workspace enthaelt Dateien!"
            else
                rm -rf "$HOME/root" "$HOME/workspace"
                rm "$HOME/Desktop/root" "$HOME/Desktop/workspace" 2>/dev/null
                zenity --info --text="X-Root Verzeichnisse entfernt."
            fi ;;
        "Cryptomator") flatpak run org.cryptomator.Cryptomator & ;;
        "Insync") insync show & ;;
        "Uninstall (Vollstaendig)") run_uninstall_full ;;
        "Beenden"|"") rm "$LOCK_FILE"; exit 0 ;;
    esac
done
