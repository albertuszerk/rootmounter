#!/bin/bash
# X-Root Mounter for Linux - albertuszerk/rootmounter

CONFIG_DIR="$HOME/.config/rootmounter"
CONFIG_FILE="$CONFIG_DIR/config.ini"
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# Funktion: UUID sauber auslesen
get_selected_uuid() {
    DEVICES=$(lsblk -p -rn -o NAME,SIZE,TYPE,UUID | awk '$3=="part" {print $1 "|" $2 "|" $4}')
    CHOICE_ROW=$(echo "$DEVICES" | tr '|' '\n' | zenity --list --title="X-Root: Partition waehlen" \
        --column="Pfad" --column="Groesse" --column="UUID" --width=600 --height=400)
    echo "$CHOICE_ROW" | awk '{print $NF}'
}

# Funktion: SSD einhaengen & Software Setup
run_mount_setup() {
    # 1. UUID Wahl
    SELECTED_UUID=$(get_selected_uuid)
    [ -z "$SELECTED_UUID" ] && return

    # 2. Software Installation
    # Wir installieren zuerst software-properties-common fuer PPA Support
    echo "Bereite Installation vor..."
    sudo apt-get update
    sudo apt-get install -y software-properties-common curl

    # Cryptomator
    sudo add-apt-repository ppa:sebastian-stenzel/cryptomator -y
    
    # Insync
    curl -s https://auth.insync.io/keys/insync.asc | sudo gpg --dearmor -o /usr/share/keyrings/insync-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/insync-archive-keyring.gpg] http://apt.insync.io/ubuntu $(lsb_release -cs) non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list

    sudo apt-get update
    sudo apt-get install -y cryptomator insync

    # 3. UUID in config.ini schreiben (REPARIERT)
    sed -i "s/^UUID=.*/UUID=$SELECTED_UUID/" "$CONFIG_FILE"

    # 4. NTFS-Mounting
    sudo mkdir -p /mnt/m2_root
    FSTAB_ENTRY="UUID=$SELECTED_UUID /mnt/m2_root ntfs-3g defaults,uid=$USER_ID,gid=$GROUP_ID,umask=007 0 2"
    
    if ! grep -q "$SELECTED_UUID" /etc/fstab; then
        echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab
    fi
    sudo mount -a

    # 5. Ordner-Struktur (aus .ini lesen)
    ROOT_SUBS=$(grep "ROOT_SUBFOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    WORK_SUBS=$(grep "WORKSPACE_SUBFOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')

    mkdir -p "$HOME/root" "$HOME/workspace"
    for s in $ROOT_SUBS; do mkdir -p "$HOME/root/$s"; done
    for s in $WORK_SUBS; do mkdir -p "$HOME/workspace/$s"; done

    # 6. Reinigung
    for f in Bilder Videos Musik Dokumente Vorlagen Oeffentlich; do
        [ -d "$HOME/$f" ] && rmdir "$HOME/$f" 2>/dev/null
    done

    zenity --info --text="SSD erfolgreich eingebunden und Software installiert!"
}

# Funktion: Full Uninstall
run_uninstall_full() {
    zenity --question --text="Alles loeschen und App beenden?" || return
    sudo umount /mnt/m2_root
    sudo sed -i '/m2_root/d' /etc/fstab
    mkdir -p ~/Bilder ~/Videos ~/Dokumente
    rm "$HOME/.local/share/applications/xrootmounter.desktop"
    zenity --info --text="System bereinigt. App wird beendet."
    exit 0
}

# --- GUI SCHLEIFE ---
while true; do
    CHOICE=$(zenity --list --title="X-Root Mounter" --width=450 --height=500 \
        --column="Menue" \
        "Konfiguration editieren" \
        "SSD/M.2 einhaengen" \
        "Cryptomator" \
        "Insync" \
        "Uninstall (Vollstaendig)" \
        "Beenden")

    case $CHOICE in
        "Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "SSD/M.2 einhaengen") run_mount_setup ;;
        "Cryptomator") cryptomator & ;;
        "Insync") insync show & ;;
        "Uninstall (Vollstaendig)") run_uninstall_full ;;
        "Beenden"|"") exit 0 ;;
    esac
done
