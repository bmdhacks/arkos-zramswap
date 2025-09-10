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

# Create install script (already exists as zramswap-package/install.sh)
echo "Install script already created at zramswap-package/install.sh"

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