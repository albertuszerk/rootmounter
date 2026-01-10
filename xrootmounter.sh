#!/bin/bash
# xrootmounter.sh - X-Root Konsole

# Singleton: Nur eine Instanz erlauben
LOCK_FILE="/tmp/xrootmounter.lock"
if [ -e "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    if ps -p $PID > /dev/null; then exit 0; fi
fi
echo $$ > "$LOCK_FILE"

CONFIG_FILE="$HOME/.config/rootmounter/config.ini"

# Hilfsfunktion: Pruefen ob Verzeichnis wirklich DATEIEN enthaelt
has_files() {
    [ -d "$1" ] && [ "$(find "$1" -maxdepth 2 -type f | wc -l)" -gt 0 ]
}

# --- FUNKTIONEN --- (Inhalt wie besprochen, aber ohne Umlaute)

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

# ... (Rest der Funktionen: Konfiguration, Modifizieren, Loeschen) ...

while true; do
    CHOICE=$(zenity --list --title="X-Root Mounter" --width=450 --height=600 \
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
        "Verzeichnisse modifizieren") # Logik zum Erstellen & Standardordner entfernen
            run_modify_dirs ;;
        "Verzeichnisse loeschen (falls leer)") 
            if has_files "$HOME/root" || has_files "$HOME/workspace"; then
                zenity --error --text="Abbruch: root oder workspace enthaelt noch Dateien!"
            else
                rm -rf "$HOME/root" "$HOME/workspace"
                zenity --info --text="Verzeichnisse entfernt."
            fi ;;
        "Cryptomator") flatpak run org.cryptomator.Cryptomator & ;;
        "Insync") insync show & ;;
        "Uninstall (Vollstaendig)") # Alles rueckgaengig machen
            rm "$LOCK_FILE"; exit 0 ;;
        "Beenden"|"") rm "$LOCK_FILE"; exit 0 ;;
    esac
done
