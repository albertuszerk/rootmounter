#!/bin/bash
# xrootmounter.sh - X-Root Konsole

# Singleton: Nur eine Instanz erlauben
if [[ $(pidof -x "$(basename "$0")" | wc -w) -gt 1 ]]; then
    exit 0
fi

CONFIG_FILE="$HOME/.config/rootmounter/config.ini"

# Hilfsfunktion: Pruefen ob Verzeichnis DATEIEN enthaelt
has_files() {
    [ -d "$1" ] && [ "$(find "$1" -type f | wc -l)" -gt 0 ]
}

run_modify_dirs() {
    STD_FOLDERS=$(grep "NAMES" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    ROOT_SUBS=$(grep "ROOT_SUBFOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    WORK_SUBS=$(grep "WORKSPACE_SUBFOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')

    mkdir -p "$HOME/root" "$HOME/workspace"
    for s in $ROOT_SUBS; do mkdir -p "$HOME/root/$s"; done
    for s in $WORK_SUBS; do mkdir -p "$HOME/workspace/$s"; done
    
    ln -sf "$HOME/root" "$HOME/Desktop/root"
    ln -sf "$HOME/workspace" "$HOME/Desktop/workspace"

    for f in $STD_FOLDERS; do
        if ! has_files "$HOME/$f"; then rm -rf "$HOME/$f"; fi
    done
    xdg-user-dirs-update --set PICTURES "$HOME"
    zenity --info --text="Verzeichnisse wurden modifiziert."
}

run_delete_dirs() {
    if has_files "$HOME/root" || has_files "$HOME/workspace"; then
        zenity --error --text="Abbruch: root oder workspace enthaelt noch Dateien!"
        return
    fi
    
    rm -rf "$HOME/root" "$HOME/workspace"
    rm "$HOME/Desktop/root" "$HOME/Desktop/workspace" 2>/dev/null
    
    STD_FOLDERS=$(grep "NAMES" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    for f in $STD_FOLDERS; do mkdir -p "$HOME/$f"; done
    
    zenity --info --text="X-Root Verzeichnisse entfernt, Standardordner wiederhergestellt."
}

run_ssd_mount() {
    DEVICES=$(lsblk -p -rn -o NAME,SIZE,TYPE,UUID | awk '$3=="part" {print $1 "|" $2 "|" $4}')
    CHOICE_ROW=$(echo "$DEVICES" | tr '|' '\n' | zenity --list --title="X-Root: Partition waehlen" \
        --column="Pfad" --column="Groesse" --column="UUID" --width=600 --height=400)
    SEL_UUID=$(echo "$CHOICE_ROW" | awk '{print $NF}')
    [ -z "$SEL_UUID" ] && return
    
    sed -i "s|^UUID=.*|UUID=$SEL_UUID|" "$CONFIG_FILE"
    sudo mkdir -p /mnt/m2_root
    FSTAB_LINE="UUID=$SEL_UUID /mnt/m2_root ntfs-3g defaults,uid=$(id -u),gid=$(id -g),umask=007 0 2"
    if ! grep -q "$SEL_UUID" /etc/fstab; then echo "$FSTAB_LINE" | sudo tee -a /etc/fstab; fi
    sudo mount -a
    zenity --info --text="X-Root Storage erfolgreich eingebunden!"
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
        "SSD/M.2 einhaengen") run_ssd_mount ;;
        "Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "Verzeichnisse modifizieren") run_modify_dirs ;;
        "Verzeichnisse loeschen (falls leer)") run_delete_dirs ;;
        "Cryptomator") flatpak run org.cryptomator.Cryptomator & ;;
        "Insync") insync show & ;;
        "Uninstall (Soft)") rm "$HOME/.local/share/applications/xrootmounter.desktop"; exit 0 ;;
        "Uninstall (Vollstaendig)") 
            zenity --question --text="ACHTUNG: Dies wird die X-Root Konfiguration und den Starter komplett vom System entfernen. Fortfahren?" || continue
            sudo umount /mnt/m2_root 2>/dev/null
            sudo sed -i '/m2_root/d' /etc/fstab
            rm "$HOME/.local/share/applications/xrootmounter.desktop"
            exit 0 ;;
        "Beenden"|"") exit 0 ;;
    esac
done
