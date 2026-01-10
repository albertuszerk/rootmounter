#!/bin/bash
# xrootmounter.sh - Management App

# ... (Mount-Funktionen bleiben gleich wie vorher) ...

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
        "Konfiguration editieren") xdg-open "$HOME/.config/rootmounter/config.ini" ;;
        "Cryptomator") 
            # Startbefehl fuer Flatpak
            flatpak run org.cryptomator.Cryptomator & ;;
        "Insync") 
            # Startbefehl fuer installierte DEB Version
            insync show & ;;
        "Uninstall (Vollstaendig)") run_uninstall_full ;;
        "Beenden"|"") exit 0 ;;
    esac
done
