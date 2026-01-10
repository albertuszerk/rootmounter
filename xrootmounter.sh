#!/bin/bash
# xrootmounter.sh - X-Root Konsole (Version 30.0)

LOCK_FILE="/tmp/xrootmounter.lock"
if [ -e "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    ps -p $PID > /dev/null && exit 0
    rm "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"

CONFIG_FILE="$HOME/.config/rootmounter/config.ini"
BOOKMARKS="$HOME/.config/gtk-3.0/bookmarks"
MOUNT_PATH="/mnt/m2_root"

has_files() { [ -d "$1" ] && [ "$(find "$1" -type f | wc -l)" -gt 0 ]; }

run_modify_dirs() {
    PAIRS=$(grep "MAIN_FOLDERS" "$CONFIG_FILE" | cut -d'=' -f2 | tr ',' ' ')
    MOD_LOG="Erstellte Strukturen:\n"
    for pair in $PAIRS; do
        folder=${pair%%:*}
        color=${pair##*:}
        mkdir -p "$HOME/$folder"
        gio set -t string "$HOME/$folder" metadata::custom-icon-name "folder-$color" 2>/dev/null
        grep -q "file://$HOME/$folder" "$BOOKMARKS" || echo "file://$HOME/$folder $folder" >> "$BOOKMARKS"
        SUBS=$(grep "^$folder=" "$CONFIG_FILE" | cut -d'=' -f2)
        for s in ${SUBS//,/ }; do mkdir -p "$HOME/$folder/$s"; done
        MOD_LOG="$MOD_LOG- $folder ($color)\n"
    done
    STD_FOLDERS=$(grep "NAMES" "$CONFIG_FILE" | cut -d'=' -f2)
    for f in ${STD_FOLDERS//,/ }; do
        if [ -d "$HOME/$f" ] && ! has_files "$HOME/$f"; then 
            rm -rf "$HOME/$f"
            sed -i "/$f/d" "$BOOKMARKS" 2>/dev/null
        fi
    done
    nautilus -q
    zenity --info --text="$MOD_LOG\nSeitenleiste wurde aktualisiert."
}

# --- MENUE ---
while true; do
    SUBTITLE="<span size='small'>In 5 Schritten zum Ziel</span>"
    
    CHOICE=$(zenity --list --title="X-Root Mounter" --text="$SUBTITLE" --width=500 --height=650 \
        --column="Menue-Eintraege" \
        "1) HDD/SSD/M.2/.. anzeigen" \
        "2) SSD/M.2 einhaengen" \
        "3) Konfiguration editieren" \
        "4) Verzeichnisse modifizieren" \
        "5) Starter-Icon entfernen" \
        "ooo" \
        "Cryptomator starten" \
        "Insync starten" \
        "ooo" \
        "Verzeichnisse loeschen (falls leer)" \
        "Uninstall (Vollstaendig)" \
        "Beenden")

    case $CHOICE in
        "1) HDD/SSD/M.2/.. anzeigen") gnome-disks & ;;
        "2) SSD/M.2 einhaengen") 
            if mountpoint -q "$MOUNT_PATH"; then zenity --info --text="Bereits aktiv."; else
                DEVICES=$(lsblk -p -rn -o NAME,SIZE,TYPE,UUID | awk '$3=="part" {print $1 "|" $2 "|" $4}')
                CHOICE_ROW=$(echo "$DEVICES" | tr '|' '\n' | zenity --list --title="Partition waehlen" --column="Pfad" --column="Groesse" --column="UUID" --width=600 --height=400)
                [ ! -z "$CHOICE_ROW" ] && SEL_UUID=$(echo "$CHOICE_ROW" | awk '{print $NF}') && \
                sed -i "s|^UUID=.*|UUID=$SEL_UUID|" "$CONFIG_FILE" && sudo mkdir -p "$MOUNT_PATH" && \
                sudo mount -a && zenity --info --text="Eingebunden!"
            fi ;;
        "3) Konfiguration editieren") xdg-open "$CONFIG_FILE" ;;
        "4) Verzeichnisse modifizieren") run_modify_dirs ;;
        "5) Starter-Icon entfernen") rm "$HOME/.local/share/applications/xrootmounter.desktop"; exit 0 ;;
        "ooo") continue ;;
        "Cryptomator starten") flatpak run org.cryptomator.Cryptomator & ;;
        "Insync starten") 
            # Robuster Start: Startet den Dienst falls nicht aktiv und oeffnet das Fenster
            insync start 2>/dev/null
            sleep 1
            insync show & 
            ;;
        "Verzeichnisse loeschen (falls leer)") rm -rf "$HOME/root" "$HOME/workspace" "$HOME/workspace2"; zenity --info --text="Entfernt." ;;
        "Uninstall (Vollstaendig)") 
            zenity --question --title="Vollstaendiger Uninstall" --text="Wirklich alles entfernen?" && {
                sudo umount "$MOUNT_PATH" 2>/dev/null
                sudo sed -i "\|$MOUNT_PATH|d" /etc/fstab
                sudo rm -f /etc/modprobe.d/disable-usb-autosuspend.conf
                rm -rf "$HOME/root" "$HOME/workspace" "$HOME/workspace2"
                mkdir -p "$HOME"/{Bilder,Videos,Musik,Dokumente,Vorlagen,Oeffentlich}
                xdg-user-dirs-update --force
                rm "$HOME/.local/share/applications/xrootmounter.desktop"
                exit 0
            } ;;
        "Beenden"|"") rm "$LOCK_FILE"; exit 0 ;;
    esac
done
