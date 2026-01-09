#!/bin/bash
# X-Root Mounter for Linux - albertuszerk/rootmounter

CONFIG_DIR="$HOME/.config/rootmounter"
CONFIG_FILE="$CONFIG_DIR/config.ini"
USER_NAME=$USER

# Funktion: System-Check (Sperre prüfen)
check_system_busy() {
    if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ; then
        zenity --error --text="Das System ist belegt (Updates laufen). Bitte schlie**ss**en Sie andere Installationen."
        return 1
    fi
    return 0
}

# Funktion: Setup ausführen
run_full_setup() {
    check_system_busy || return
    
    # 1. UUID-Wahl (Geführt)
    # Wir zeigen NAME, GRÖSSE und MODELL an
    DEVICES=$(lsblk -dno NAME,SIZE,MODEL | awk '{print $1 " - " $2 " - " $3}')
    CHOICE=$(zenity --list --title="X-Root: SSD wählen" --width=500 --height=300 \
             --column="Wähle deine M.2 SSD" $DEVICES)
    
    [ -z "$CHOICE" ] && return
    DISK_NAME=$(echo $CHOICE | awk '{print $1}')
    # UUID sauber auslesen
    SELECTED_UUID=$(lsblk -dno UUID /dev/$DISK_NAME)
    
    if [ -z "$SELECTED_UUID" ]; then
        zenity --error --text="Fehler: Keine UUID für /dev/$DISK_NAME gefunden!"
        return
    fi

    # 2. Software-Quellen hinzufügen (Cryptomator & Insync)
    zenity --info --text="Füge Software-Quellen hinzu und installiere Apps..." --timeout=2
    sudo add-apt-repository ppa:phoerious/keepassxc -y # Beispiel für PPA
    sudo add-apt-repository ppa:sebastian-stenzel/cryptomator -y
    
    # Insync Repo (spezifisch für Ubuntu/Zorin)
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ACCAF35C
    echo "deb http://apt.insync.io/ubuntu $(lsb_release -cs) non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list

    sudo apt update
    sudo apt install -y cryptomator insync

    # 3. Mount in fstab
    sudo mkdir -p /mnt/m2_root
    # Prüfen, ob Eintrag schon existiert, sonst hinzufügen
    if ! grep -q "$SELECTED_UUID" /etc/fstab; then
        echo "UUID=$SELECTED_UUID /mnt/m2_root ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
    fi
    sudo mount -a
    sudo chown -R $USER_NAME:$USER_NAME /mnt/m2_root

    # 4. Ordner-Struktur (Root)
    ROOT_PATH="$HOME/root"
    SUB_ROOT="backup client clientpic clientshare1 control db document gallery project replicate shareprg softinst softinst-shared temp template web whitepaper"
    
    # 5. Ordner-Struktur (Workspace)
    WORK_PATH="$HOME/workspace"
    SUB_WORK="user-backup user-control user-db user-document user-download user-favorites user-gallery user-template user-web"

    mkdir -p "$ROOT_PATH" "$WORK_PATH"

    for sub in $SUB_ROOT; do mkdir -p "$ROOT_PATH/$sub"; done
    for sub in $SUB_WORK; do mkdir -p "$WORK_PATH/$sub"; done

    # 6. Reinigung
    for folder in Bilder Videos Musik Dokumente Vorlagen Öffentlich; do
        [ -d "$HOME/$folder" ] && rmdir "$HOME/$folder" 2>/dev/null
    done

    # UUID in lokaler Config speichern
    sed -i "s/UUID=.*/UUID=$SELECTED_UUID/" "$CONFIG_FILE"
    
    zenity --info --text="X-Root Setup erfolgreich abgeschlossen!"
}

# --- HAUPTSCHLEIFE (Hält die App offen) ---
while true; do
    CHOICE=$(zenity --list --title="X-Root Mounter for Linux" --width=450 --height=500 \
        --column="Menü" \
        "System-Setup ausführen" \
        "Cryptomator" \
        "Insync" \
        "Konfiguration editieren" \
        "Uninstall (Soft)" \
        "Uninstall (Vollständig)" \
        "Beenden")

    case $CHOICE in
        "System-Setup ausführen") run_full_setup ;;
        "Cryptomator") cryptomator & ;;
        "Insync") insync show & ;;
        "Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "Uninstall (Vollständig)") 
            zenity --question --text="Möchten Sie wirklich alles rückgängig machen?" && \
            mkdir -p ~/Bilder ~/Videos ~/Dokumente && \
            zenity --info --text="Standardordner wiederhergestellt."
            ;;
        "Beenden"|"") exit 0 ;;
    esac
done
