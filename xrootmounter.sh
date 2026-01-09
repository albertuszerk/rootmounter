#!/bin/bash
# X-Root Mounter for Linux - albertuszerk/rootmounter

CONFIG_FILE="$HOME/.config/rootmounter/config.ini"
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# Funktion: UUID sauber auslesen
get_selected_uuid() {
    # Wir listen NAME, SIZE, TYPE und UUID getrennt durch ein Sonderzeichen auf
    DEVICES=$(lsblk -p -rn -o NAME,SIZE,TYPE,UUID | awk '$3=="part" {print $1 "|" $2 "|" $4}')
    
    # Zenity-Liste vorbereiten
    CHOICE_ROW=$(echo "$DEVICES" | tr '|' '\n' | zenity --list --title="X-Root: Partition wählen" \
        --column="Pfad" --column="Grösse" --column="UUID" --width=600 --height=400)
    
    # Die UUID ist das letzte Element in der Wahl
    echo "$CHOICE_ROW" | awk '{print $NF}'
}

# Funktion: Setup
run_full_setup() {
    # 1. UUID Wahl
    SELECTED_UUID=$(get_selected_uuid)
    [ -z "$SELECTED_UUID" ] && return

    # 2. Software Installation (mit Terminal-Sichtbarkeit für Passwort)
    echo "Installiere Cryptomator und Insync..."
    sudo add-apt-repository ppa:sebastian-stenzel/cryptomator -y
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ACCAF35C
    echo "deb http://apt.insync.io/ubuntu $(lsb_release -cs) non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list
    sudo apt update && sudo apt install -y cryptomator insync

    # 3. NTFS-Mounting mit User-Rechten
    sudo mkdir -p /mnt/m2_root
    # Eintrag für fstab vorbereiten (NTFS-spezifisch für Schreibrechte)
    FSTAB_ENTRY="UUID=$SELECTED_UUID /mnt/m2_root ntfs-3g defaults,uid=$USER_ID,gid=$GROUP_ID,umask=007 0 2"
    
    if ! grep -q "$SELECTED_UUID" /etc/fstab; then
        echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab
    fi
    sudo mount -a

    # 4. Ordner-Struktur (Liest aus .ini)
    ROOT_SUBS=$(grep "ROOT_SUBFOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    WORK_SUBS=$(grep "WORKSPACE_SUBFOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')

    mkdir -p "$HOME/root" "$HOME/workspace"
    for s in $ROOT_SUBS; do mkdir -p "$HOME/root/$s"; done
    for s in $WORK_SUBS; do mkdir -p "$HOME/workspace/$s"; done

    # 5. Reinigung
    for f in Bilder Videos Musik Dokumente Vorlagen Öffentlich; do
        [ -d "$HOME/$f" ] && rmdir "$HOME/$f" 2>/dev/null
    done

    zenity --info --text="Setup erfolgreich!"
}

# Funktion: Full Uninstall
run_uninstall_full() {
    zenity --question --text="Alles löschen und App beenden?" || return
    sudo umount /mnt/m2_root
    sudo sed -i '/m2_root/d' /etc/fstab
    mkdir -p ~/Bilder ~/Videos ~/Dokumente
    # App-Dateien löschen
    rm "$HOME/.local/share/applications/xrootmounter.desktop"
    zenity --info --text="System bereinigt. App wird beendet."
    exit 0 # Hier wird die App schlie**ss**lich beendet
}

# --- GUI SCHLEIFE ---
while true; do
    CHOICE=$(zenity --list --title="X-Root Mounter" --width=450 --height=500 \
        --column="Menü" \
        "System-Setup ausführen" \
        "Cryptomator" \
        "Insync" \
        "Konfiguration editieren" \
        "Uninstall (Vollständig)" \
        "Beenden")

    case $CHOICE in
        "System-Setup ausführen") run_full_setup ;;
        "Cryptomator") cryptomator & ;;
        "Insync") insync show & ;;
        "Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "Uninstall (Vollständig)") run_uninstall_full ;;
        "Beenden"|"") exit 0 ;;
    esac
done
