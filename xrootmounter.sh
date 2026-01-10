#!/bin/bash
# xrootmounter.sh - X-Root Management Konsole

CONFIG_DIR="$HOME/.config/rootmounter"
CONFIG_FILE="$CONFIG_DIR/config.ini"
USER_HOME=$HOME

# Hilfsfunktion: Pruefen ob Verzeichnis leer ist
is_empty() {
    [ -d "$1" ] && [ -z "$(ls -A "$1")" ]
}

# 1. Verzeichnisse modifizieren (Erstellen & Standardordner entfernen)
run_modify_dirs() {
    # X-Root Struktur erstellen
    ROOT_SUBS=$(grep "ROOT_SUBFOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    WORK_SUBS=$(grep "WORKSPACE_SUBFOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    
    mkdir -p "$USER_HOME/root" "$USER_HOME/workspace"
    for s in $ROOT_SUBS; do mkdir -p "$USER_HOME/root/$s"; done
    for s in $WORK_SUBS; do mkdir -p "$USER_HOME/workspace/$s"; done
    
    # Desktop Links
    ln -sf "$USER_HOME/root" "$USER_HOME/Desktop/root"
    ln -sf "$USER_HOME/workspace" "$USER_HOME/Desktop/workspace"

    # Standardordner entfernen (NUR WENN LEER)
    for f in Bilder Videos Musik Dokumente Vorlagen Oeffentlich; do
        if is_empty "$USER_HOME/$f"; then
            rm -rf "$USER_HOME/$f"
        fi
    done
    
    # Geisterordner in Seitenleiste fixen
    xdg-user-dirs-update --set PICTURES "$USER_HOME"
    xdg-user-dirs-update --set VIDEOS "$USER_HOME"
    
    zenity --info --text="Verzeichnisse wurden gemaess Konfiguration modifiziert."
}

# 2. Verzeichnisse loeschen (Sicherheits-Check)
run_delete_dirs() {
    # Pruefen ob root oder workspace Daten enthalten
    if ! is_empty "$USER_HOME/root" || ! is_empty "$USER_HOME/workspace"; then
        zenity --error --text="Abbruch: root oder workspace Verzeichnis ist nicht leer!"
        return
    fi
    
    # Loeschen
    rm -rf "$USER_HOME/root" "$USER_HOME/workspace"
    rm "$USER_HOME/Desktop/root" "$USER_HOME/Desktop/workspace" 2>/dev/null
    
    # Standardordner wiederherstellen
    mkdir -p ~/Bilder ~/Videos ~/Musik ~/Dokumente
    xdg-user-dirs-update --set PICTURES "$USER_HOME/Bilder"
    xdg-user-dirs-update --set VIDEOS "$USER_HOME/Videos"
    
    zenity --info --text="X-Root Verzeichnisse geloescht und Standardordner wiederhergestellt."
}

# 3. SSD Einhaengen
run_ssd_mount() {
    DEVICES=$(lsblk -p -rn -o NAME,SIZE,TYPE,UUID | awk '$3=="part" {print $1 "|" $2 "|" $4}')
    CHOICE_ROW=$(echo "$DEVICES" | tr '|' '\n' | zenity --list --title="X-Root: Partition waehlen" \
        --column="Pfad" --column="Groesse" --column="UUID" --width=600 --height=400)
    SEL_UUID=$(echo "$CHOICE_ROW" | awk '{print $NF}')
    [ -z "$SEL_UUID" ] && return
    
    sed -i "s|^UUID=.*|UUID=$SEL_UUID|" "$CONFIG_FILE"
    sudo mkdir -p /mnt/m2_root
    FSTAB_LINE="UUID=$SEL_UUID /mnt/m2_root ntfs-3g defaults,uid=$(id -u),gid=$(id -g),umask=007 0 2"
    if ! grep -q "$SEL_UUID" /etc/fstab; then
        echo "$FSTAB_LINE" | sudo tee -a /etc/fstab
    fi
    sudo mount -a
    zenity --info --text="SSD erfolgreich eingebunden!"
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
            sudo umount /mnt/m2_root 2>/dev/null
            sudo sed -i '/m2_root/d' /etc/fstab
            rm "$HOME/.local/share/applications/xrootmounter.desktop"
            exit 0 ;;
        "Beenden"|"") exit 0 ;;
    esac
done
