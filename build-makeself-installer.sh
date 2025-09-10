#!/bin/bash

set -e

echo "Building ZRAM Swap Installer with Makeself..."
echo "============================================="

# Check if makeself is available
if ! command -v makeself >/dev/null 2>&1; then
    echo "ERROR: makeself not found!"
    echo "Install with: sudo apt install makeself"
    exit 1
fi

# Check if deb files exist
if ! ls *.deb >/dev/null 2>&1; then
    echo "ERROR: No .deb files found in current directory!"
    echo "Expected files:"
    echo "  - zram-config_*.deb"
    echo "  - zram-tools_*.deb"
    exit 1
fi

# Clean up any existing files
echo "Cleaning up previous builds..."
rm -rf zramswap-package zramswap-installer.sh

# Create package directory
echo "Creating package directory..."
mkdir -p zramswap-package

# Copy deb packages
echo "Copying .deb packages..."
cp *.deb zramswap-package/

# Copy install script from template
echo "Copying install script..."
cp zramswap-package/install.sh zramswap-package/install.sh.tmp 2>/dev/null || true
if [ ! -f zramswap-package/install.sh ]; then
    echo "Creating install script from template..."
    cat > zramswap-package/install.sh << 'EOF'
#!/bin/bash

# --- Parse arguments ---
AUTO_YES=false
if [[ "$*" == *"--yes"* ]]; then
    AUTO_YES=true
fi

# --- Root check ---
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -- "$0" "$@"
fi
set -euo pipefail

CURR_TTY="/dev/tty1"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# --- Initial Setup ---
if [ "$AUTO_YES" = "false" ]; then
    printf "\033c" > "$CURR_TTY"
    printf "\e[?25l" > "$CURR_TTY" # hide cursor
    export TERM=linux

    # Try to set a nice font if available
    if [ -f /usr/share/consolefonts/Lat7-Terminus16.psf.gz ]; then
        setfont /usr/share/consolefonts/Lat7-Terminus16.psf.gz 2>/dev/null || true
    fi

    printf "\033c" > "$CURR_TTY"
    printf "ZRAM Swap Installer\nPlease wait..." > "$CURR_TTY"
    sleep 1
fi

# --- Functions ---
cleanup() {
    if [ "$AUTO_YES" = "false" ]; then
        printf "\033c" > "$CURR_TTY"
        printf "\e[?25h" > "$CURR_TTY" # show cursor
    fi
}

get_system_info() {
    local mem_total mem_free swap_total
    mem_total=$(awk '/MemTotal:/ {printf "%.1f GB", $2/1024/1024}' /proc/meminfo)
    mem_free=$(awk '/MemAvailable:/ {printf "%.1f GB", $2/1024/1024}' /proc/meminfo)
    swap_total=$(awk '/SwapTotal:/ {printf "%.1f GB", $2/1024/1024}' /proc/meminfo)
    echo -e "Total Memory: $mem_total\nAvailable Memory: $mem_free\nCurrent Swap: $swap_total"
}

check_zram_status() {
    if command -v zramctl >/dev/null 2>&1; then
        local zram_info
        zram_info=$(zramctl 2>/dev/null | tail -n +2)
        if [ -n "$zram_info" ]; then
            echo -e "ZRAM already configured:\n$zram_info"
            return 0
        fi
    fi
    echo "No ZRAM devices currently configured"
    return 1
}

install_packages() {
    if [ "$AUTO_YES" = "true" ]; then
        echo "Installing packages with dpkg..."
        echo "DEBUG: Available .deb files in $SCRIPT_DIR:"
        ls -la "$SCRIPT_DIR"/*.deb
    else
        dialog --infobox "Installing packages with dpkg..." 5 40 > "$CURR_TTY"
    fi
    
    if ! dpkg -i "$SCRIPT_DIR"/*.deb 2>/dev/null; then
        if [ "$AUTO_YES" = "true" ]; then
            echo "ERROR: Package installation failed! Check dependencies."
        else
            dialog --msgbox "Package installation failed! Check dependencies." 8 50 > "$CURR_TTY"
        fi
        return 1
    fi
    
    if [ "$AUTO_YES" = "true" ]; then
        echo "Configuring zramswap..."
    else
        dialog --infobox "Configuring zramswap..." 5 30 > "$CURR_TTY"
    fi
    
    # Check for different possible config file locations
    ZRAM_CONFIG=""
    for config_path in "/etc/default/zramswap" "/etc/zram-config" "/etc/default/zram-config"; do
        if [ -f "$config_path" ]; then
            ZRAM_CONFIG="$config_path"
            break
        fi
    done
    
    if [ -n "$ZRAM_CONFIG" ]; then
        if [ "$AUTO_YES" = "true" ]; then
            echo "DEBUG: Found config file: $ZRAM_CONFIG"
            echo "DEBUG: Original config:"
            cat "$ZRAM_CONFIG"
        fi
        
        sed -i 's/^#ALLOCATION=.*/ALLOCATION=3072/' "$ZRAM_CONFIG"
        sed -i 's/^#\s*ALLOCATION=.*/ALLOCATION=3072/' "$ZRAM_CONFIG"
        
        if [ "$AUTO_YES" = "true" ]; then
            echo "DEBUG: Modified config:"
            cat "$ZRAM_CONFIG"
        fi
    else
        if [ "$AUTO_YES" = "true" ]; then
            echo "ERROR: No zramswap config file found!"
            echo "DEBUG: Searched for:"
            echo "  /etc/default/zramswap"
            echo "  /etc/zram-config" 
            echo "  /etc/default/zram-config"
        else
            dialog --msgbox "Warning: No zramswap config file found!" 8 50 > "$CURR_TTY"
        fi
        return 1
    fi
    
    if [ "$AUTO_YES" = "true" ]; then
        echo "Installation completed successfully!"
        echo "ZRAM swap configured (~768MB usable)."
        echo "Reboot to activate zram swap."
    else
        dialog --msgbox "Installation completed successfully!\n\nZRAM swap configured (~768MB usable).\nReboot to activate zram swap." 10 60 > "$CURR_TTY"
    fi
    return 0
}

ExitMenu() {
    pkill -f "gptokeyb -1 zramswap-installer.sh" || true
    cleanup
    exit 0
}

MainMenu() {
    while true; do
        local SYS_INFO ZRAM_STATUS
        SYS_INFO=$(get_system_info)
        ZRAM_STATUS=$(check_zram_status || true)
        
        local CHOICE
        CHOICE=$(dialog --output-fd 1 \
            --backtitle "ZRAM Swap Installer" \
            --title "System Information" \
            --menu "Current System Status:\n$SYS_INFO\n\nZRAM Status:\n$ZRAM_STATUS" 20 70 10 \
            1 "Install ZRAM Swap (~768MB usable)" \
            2 "Exit" \
            2>"$CURR_TTY")

        case $CHOICE in
            1) 
                if dialog --yesno "This will install zram-config and zram-tools packages and configure ~768MB of zram swap.\n\nContinue?" 10 60 > "$CURR_TTY"; then
                    if install_packages; then
                        if dialog --yesno "Installation complete!\n\nWould you like to reboot now to activate zram swap?" 10 60 > "$CURR_TTY"; then
                            dialog --infobox "Rebooting in 3 seconds..." 5 30 > "$CURR_TTY"
                            sleep 3
                            reboot
                        fi
                    fi
                fi
                ;;
            2) ExitMenu ;;
            *) ExitMenu ;;
        esac
    done
}

# --- Main Execution ---
trap ExitMenu EXIT SIGINT SIGTERM

# Non-interactive mode with --yes
if [ "$AUTO_YES" = "true" ]; then
    echo "ZRAM Swap Installer - Non-interactive mode"
    echo "=========================================="
    echo
    get_system_info
    echo
    check_zram_status || true
    echo
    echo "Installing ZRAM swap packages..."
    if install_packages; then
        echo
        echo "Installation complete! Reboot to activate zram swap."
    else
        echo "Installation failed!"
        exit 1
    fi
    exit 0
fi

# Check if dialog is available
if ! command -v dialog >/dev/null 2>&1; then
    printf "\033c" > "$CURR_TTY"
    printf "Error: dialog not found!\nInstall with: apt-get install dialog\n" > "$CURR_TTY"
    printf "\e[?25h" > "$CURR_TTY"
    exit 1
fi

# gptokeyb setup for joystick control
if command -v /opt/inttools/gptokeyb &> /dev/null; then
    [[ -e /dev/uinput ]] && chmod 666 /dev/uinput 2>/dev/null || true
    export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
    pkill -f "gptokeyb -1 zramswap-installer.sh" || true
    /opt/inttools/gptokeyb -1 "zramswap-installer.sh" -c "/opt/inttools/keys.gptk" >/dev/null 2>&1 &
else
    dialog --infobox "gptokeyb not found. Joystick control disabled." 5 65 > "$CURR_TTY"
    sleep 2
fi

printf "\033c" > "$CURR_TTY"
MainMenu
EOF
fi

# Make install script executable
chmod +x zramswap-package/install.sh

# List package contents
echo ""
echo "Package contents:"
ls -la zramswap-package/

# Create makeself installer
echo ""
echo "Creating makeself installer..."
makeself --nox11 --gzip zramswap-package zramswap-installer.sh "ZRAM Swap Installer" ./install.sh

# Show final result
echo ""
echo "Build complete!"
echo "==============="
echo "Final installer: zramswap-installer.sh"
echo "Size: $(stat -c%s zramswap-installer.sh) bytes"
echo ""
echo "Usage:"
echo "  Interactive mode:     ./zramswap-installer.sh"
echo "  Non-interactive mode: ./zramswap-installer.sh --yes"
echo ""
echo "The installer can also be unpacked without running:"
echo "  ./zramswap-installer.sh --target /tmp/zramswap-extracted --noexec"