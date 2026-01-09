#!/bin/bash
# xrootmounter.sh - Die Hauptanwendung

# Variablen
CONFIG_FILE="$HOME/.config/rootmounter/config.ini"
USER_NAME=$USER

# Funktion: System-Check (Sperre prüfen)
check_system_busy() {
    if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ; then
        zenity --error --text="Das System ist belegt (Updates laufen). Bitte schlie**ss**en Sie andere Installationen."
        exit 1
    fi
}

# Funktion: UUID-Assistent
get_uuid_gui() {
    LIST=$(lsblk -dno NAME,SIZE,MODEL | awk '{print $1 " (" $2 " - " $3 ")"}')
    CHOICE=$(zenity --list --title="X-Root: SSD wählen" --column="Verfügbare Laufwerke" $LIST)
    DISK_NAME=$(echo $CHOICE | awk '{print $1}')
    UUID=$(lsblk -dno UUID /dev/$DISK_NAME)
    echo "$UUID"
}

# Funktion: Setup ausführen
run_setup() {
    check_system_busy
    
    # 1. UUID holen
    MY_UUID=$(get_uuid_gui)
    [ -z "$MY_UUID" ] && return

    # 2. Software installieren
    zenity --info --text="Installiere Cryptomator und Insync..."
    sudo apt update && sudo apt install -y cryptomator
    # Hinweis: Insync Repo-Logik hier einfügen falls nötig

    # 3. fstab schreiben
    sudo mkdir -p /mnt/m2_root
    echo "UUID=$MY_UUID /mnt/m2_root ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
    sudo mount -a
    sudo chown -R $USER_NAME:$USER_NAME /mnt/m2_root

    # 4. Ordner-Hygiene (Löschen)
    # Entfernt Bilder, Videos etc. physisch wenn leer
    for folder in Bilder Videos Musik Dokumente Vorlagen Öffentlich; do
        rmdir "$HOME/$folder" 2>/dev/null
    done
    xdg-user-dirs-update --set DOWNLOAD "$HOME/workspace/user-download"

    # 5. Struktur erstellen
    mkdir -p "$HOME/root" "$HOME/workspace"
    # (Hier folgt die Schleife für alle Subfolder aus der .ini)
    
    zenity --info --text="X-Root erfolgreich eingerichtet!"
}

# HAUPTMENÜ (GUI)
CHOICE=$(zenity --list --title="X-Root Mounter" --width=400 --height=400 \
    --column="Aktion" \
    "System-Setup ausführen" \
    "Cryptomator starten" \
    "Insync starten" \
    "Konfiguration editieren" \
    "Uninstall (Nur App)" \
    "Uninstall (Vollständig)")

case $CHOICE in
    "System-Setup ausführen") run_setup ;;
    "Cryptomator starten") cryptomator & ;;
    "Insync starten") insync show & ;;
    "Konfiguration editieren") nano "$CONFIG_FILE" ;;
    "Uninstall (Vollständig)") 
        # Logik zum Wiederherstellen der Standardordner
        mkdir -p "$HOME/Bilder" "$HOME/Videos" "$HOME/Dokumente"
        xdg-user-dirs-update --set PICTURES "$HOME/Bilder"
        zenity --info --text="System wurde auf Standard zurückgesetzt."
        ;;
esac
