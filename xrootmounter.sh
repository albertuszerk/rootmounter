#!/bin/bash
# xrootmounter.sh - Management App

CONFIG_FILE="$HOME/.config/rootmounter/config.ini"

save_uuid_to_config() {
    sed -i "s|^UUID=.*|UUID=$1|" "$CONFIG_FILE"
}

run_ssd_mount() {
    DEVICES=$(lsblk -p -rn -o NAME,SIZE,TYPE,UUID | awk '$3=="part" {print $1 "|" $2 "|" $4}')
    CHOICE_ROW=$(echo "$DEVICES" | tr '|' '\n' | zenity --list --title="X-Root: Partition waehlen" \
        --column="Pfad" --column="Groesse" --column="UUID" --width=600 --height=400)
    
    SEL_UUID=$(echo "$CHOICE_ROW" | awk '{print $NF}')
    [ -z "$SEL_UUID" ] && return

    save_uuid_to_config "$SEL_UUID"

    sudo mkdir -p /mnt/m2_root
    # NTFS Mount mit User-Rechten
    FSTAB_LINE="UUID=$SEL_UUID /mnt/m2_root ntfs-3g defaults,uid=$(id -u),gid=$(id -g),umask=007 0 2"
    
    if ! grep -q "$SEL_UUID" /etc/fstab; then
        echo "$FSTAB_LINE" | sudo tee -a /etc/fstab
    fi
    sudo mount -a

    # Ordner-Struktur erstellen
    ROOT_SUBS=$(grep "ROOT_SUBFOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    WORK_SUBS=$(grep "WORKSPACE_SUBFOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    mkdir -p "$HOME/root" "$HOME/workspace"
    for s in $ROOT_SUBS; do mkdir -p "$HOME/root/$s"; done
    for s in $WORK_SUBS; do mkdir -p "$HOME/workspace/$s"; done

    zenity --info --text="SSD erfolgreich eingebunden!"
}

run_uninstall_full() {
    zenity --question --text="System zuruecksetzen?" || return
    sudo umount /mnt/m2_root 2>/dev/null
    sudo sed -i '/m2_root/d' /etc/fstab
    
    # Desktop Links entfernen
    DESKTOP_DIR=$(xdg-user-dir DESKTOP)
    rm "$DESKTOP_DIR/root" "$DESKTOP_DIR/workspace"
    
    # Ordner wiederherstellen
    mkdir -p ~/Bilder ~/Videos ~/Musik ~/Dokumente
    xdg-user-dirs-update --set PICTURES "$HOME/Bilder"
    xdg-user-dirs-update --set VIDEOS "$HOME/Videos"
    
    rm "$HOME/.local/share/applications/xrootmounter.desktop"
    zenity --info --text="Deinstallation fertig. App beendet."
    exit 0
}

# --- HAUPTMENUE ---
while true; do
    CHOICE=$(zenity --list --title="X-Root Mounter" --width=400 --height=450 \
        --column="Menue" \
        "SSD/M.2 einhaengen" \
        "Konfiguration editieren" \
        "Cryptomator" \
        "Insync" \
        "Uninstall (Vollstaendig)" \
        "Beenden")

    case $CHOICE in
        "SSD/M.2 einhaengen") run_ssd_mount ;;
        "Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "Cryptomator") 
            if command -v cryptomator >/dev/null; then cryptomator & else zenity --error --text="Cryptomator nicht gefunden!"; fi ;;
        "Insync") 
            if command -v insync >/dev/null; then insync show & else zenity --error --text="Insync nicht gefunden!"; fi ;;
        "Uninstall (Vollstaendig)") run_uninstall_full ;;
        "Beenden"|"") exit 0 ;;
    esac
done
