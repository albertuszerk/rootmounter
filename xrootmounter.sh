#!/bin/bash
# xrootmounter.sh - Management App

CONFIG_FILE="$HOME/.config/rootmounter/config.ini"

# Funktion: UUID in die .ini schreiben (Verbessert)
save_uuid_to_config() {
    local new_uuid=$1
    # Wir nutzen ein temporaeres File, um Schreibfehler zu vermeiden
    sed -i "s|^UUID=.*|UUID=$new_uuid|" "$CONFIG_FILE"
}

# Funktion: SSD einhaengen
run_ssd_mount() {
    # Partition waehlen
    DEVICES=$(lsblk -p -rn -o NAME,SIZE,TYPE,UUID | awk '$3=="part" {print $1 "|" $2 "|" $4}')
    CHOICE_ROW=$(echo "$DEVICES" | tr '|' '\n' | zenity --list --title="X-Root: Partition waehlen" \
        --column="Pfad" --column="Groesse" --column="UUID" --width=600 --height=400)
    
    SEL_UUID=$(echo "$CHOICE_ROW" | awk '{print $NF}')
    
    if [ -z "$SEL_UUID" ]; then
        zenity --error --text="Keine UUID gefunden!"
        return
    fi

    # UUID speichern
    save_uuid_to_config "$SEL_UUID"

    # Mounten (Sudo wird hier gezielt abgefragt)
    sudo mkdir -p /mnt/m2_root
    FSTAB_LINE="UUID=$SEL_UUID /mnt/m2_root ntfs-3g defaults,uid=$(id -u),gid=$(id -g),umask=007 0 2"
    
    if ! grep -q "$SEL_UUID" /etc/fstab; then
        echo "$FSTAB_LINE" | sudo tee -a /etc/fstab
    fi
    sudo mount -a

    # Ordner in Home erstellen (aus Config lesen)
    ROOT_SUBS=$(grep "ROOT_SUBFOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    WORK_SUBS=$(grep "WORKSPACE_SUBFOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')

    mkdir -p "$HOME/root" "$HOME/workspace"
    for s in $ROOT_SUBS; do mkdir -p "$HOME/root/$s"; done
    for s in $WORK_SUBS; do mkdir -p "$HOME/workspace/$s"; done

    zenity --info --text="SSD erfolgreich eingebunden!"
}

# --- HAUPTMENUE ---
while true; do
    CHOICE=$(zenity --list --title="X-Root Mounter" --width=400 --height=450 \
        --column="Menue" \
        "Konfiguration editieren" \
        "SSD/M.2 einhaengen" \
        "Cryptomator" \
        "Insync" \
        "Uninstall (Vollstaendig)" \
        "Beenden")

    case $CHOICE in
        "Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "SSD/M.2 einhaengen") run_ssd_mount ;;
        "Cryptomator") cryptomator & ;;
        "Insync") insync show & ;;
        "Uninstall (Vollstaendig)") 
            sudo sed -i '/m2_root/d' /etc/fstab
            sudo umount /mnt/m2_root
            exit 0 ;;
        "Beenden"|"") exit 0 ;;
    esac
done
