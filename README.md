# ZRAM Swap Installer for ArkOS Handhelds

A self-extracting installer for adding ZRAM swap support to ArkOS handheld devices like the R36S. This installer provides compressed RAM-based swap to improve performance on memory-constrained devices.

## Quick Start

Download `zramswap-installer.sh`, copy it to your roms sdcard in the
tools section and run it from the Options -> Tools menu

## Building from Source

### Prerequisites

Requires the `makeself` tool

### Build Process
```bash
./build-makeself-installer.sh
```

This will create `zramswap-installer.sh` - a self-contained installer.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

