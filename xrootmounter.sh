#!/bin/bash
# X-Root Mounter for Linux - albertuszerk/rootmounter

CONFIG_DIR="$HOME/.config/rootmounter"
CONFIG_FILE="$CONFIG_DIR/config.ini"
USER_NAME=$USER

# Funktion: System-Sperre prüfen
check_system_busy() {
    if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ; then
        zenity --error --text="Das System ist belegt (Updates laufen). Bitte schlie**ss**en Sie andere Installationen."
        return 1
    fi
    return 0
}

# Funktion: Full Setup
run_full_setup() {
    check_system_busy || return
    
    # 1. Auswahl der PARTITION (Nicht des Laufwerks)
    # Wir filtern nach 'part' (Partitionen), damit eine UUID vorhanden ist.
    DEVICES=$(lsblk -p -rn -o NAME,SIZE,TYPE,MODEL,UUID | awk '$3=="part" {print $1 " (" $2 " - " $4 ") " $5}')
    
    if [ -z "$DEVICES" ]; then
        zenity --error --text="Keine Partitionen gefunden. Ist die SSD eingesteckt?"
        return
    fi

    CHOICE=$(zenity --list --title="X-Root: Partition wählen" --width=600 --height=400 \
             --column="Partition (Pfad - Grösse - Modell) UUID" $DEVICES)
    
    [ -z "$CHOICE" ] && return
    
    # Extrahiere Pfad und UUID
    SELECTED_PART=$(echo $CHOICE | awk '{print $1}')
    SELECTED_UUID=$(echo $CHOICE | awk '{print $NF}')

    if [ -z "$SELECTED_UUID" ] || [ "$SELECTED_UUID" == "$SELECTED_PART" ]; then
        zenity --error --text="Fehler: Diese Partition hat keine gültige UUID. Bitte formatiere sie zuerst (z.B. ext4)."
        return
    fi

    # 2. Software Installation (Verbessert)
    zenity --info --text="Installiere Cryptomator & Insync. Bitte Passwort im Terminal eingeben, falls abgefragt." --timeout=3
    
    # Cryptomator PPA
    sudo add-apt-repository ppa:sebastian-stenzel/cryptomator -y
    
    # Insync Key & Repo
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ACCAF35C 2>/dev/null
    echo "deb http://apt.insync.io/ubuntu $(lsb_release -cs) non-free contrib" | sudo tee /etc/apt/sources.list.d/insync.list

    sudo apt update
    sudo apt install -y cryptomator insync

    # 3. Mount-Logik
    sudo mkdir -p /mnt/m2_root
    if ! grep -q "$SELECTED_UUID" /etc/fstab; then
        echo "UUID=$SELECTED_UUID /mnt/m2_root ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
    fi
    sudo mount -a
    sudo chown -R $USER_NAME:$USER_NAME /mnt/m2_root

    # 4. Verzeichnisse erstellen
    ROOT_SUB="backup client clientpic clientshare1 control db document gallery project replicate shareprg softinst softinst-shared temp template web whitepaper"
    WORK_SUB="user-backup user-control user-db user-document user-download user-favorites user-gallery user-template user-web"

    mkdir -p "$HOME/root" "$HOME/workspace"
    for s in $ROOT_SUB; do mkdir -p "$HOME/root/$s"; done
    for s in $WORK_SUB; do mkdir -p "$HOME/workspace/$s"; done

    # 5. Reinigung (Physisches Löschen leerer Standardordner)
    for f in Bilder Videos Musik Dokumente Vorlagen Öffentlich; do
        [ -d "$HOME/$f" ] && rmdir "$HOME/$f" 2>/dev/null
    done

    # UUID speichern
    sed -i "s/UUID=.*/UUID=$SELECTED_UUID/" "$CONFIG_FILE" 2>/dev/null
    
    zenity --info --text="Setup abgeschlossen! Deine SSD ist als m2_root gemountet."
}

# Funktion: Vollständiger Rückbau
run_uninstall_full() {
    zenity --question --text="Möchten Sie ALLES rückgängig machen? (Mounts entfernen, Standardordner wiederherstellen)" || return
    
    # 1. Unmount & fstab Reinigung
    sudo umount /mnt/m2_root 2>/dev/null
    sudo sed -i '/m2_root/d' /etc/fstab
    sudo rmdir /mnt/m2_root 2>/dev/null
    
    # 2. Standardordner wiederherstellen
    mkdir -p ~/Bilder ~/Videos ~/Musik ~/Dokumente ~/Vorlagen ~/Öffentlich
    xdg-user-dirs-update --set PICTURES "$HOME/Bilder"
    xdg-user-dirs-update --set VIDEOS "$HOME/Videos"
    
    # 3. App-Verzeichnisse löschen (Optional, nur wenn leer)
    rmdir "$HOME/root" "$HOME/workspace" 2>/dev/null

    zenity --info --text="System erfolgreich bereinigt. Apps (Cryptomator/Insync) bleiben installiert."
}

# --- GUI SCHLEIFE ---
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
        "Uninstall (Soft)") rm "$HOME/.local/share/applications/xrootmounter.desktop"; exit 0 ;;
        "Uninstall (Vollständig)") run_uninstall_full ;;
        "Beenden"|"") exit 0 ;;
    esac
done
