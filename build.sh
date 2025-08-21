#!/bin/bash
# Package Updates Noty - Build Script
# Creates a standalone binary from the Python script

set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
BUILD_DIR="$SCRIPT_DIR/build"

log() { echo -e "${GREEN}[BUILD]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

cd "$SCRIPT_DIR"

# Check dependencies
log "Checking build dependencies..."

# Check if Python 3 is available
if ! command -v python3 >/dev/null 2>&1; then
    error "Python 3 is required for building"
fi

# Clean previous build
log "Cleaning previous build..."
rm -rf "$DIST_DIR" "$BUILD_DIR/pyinstaller"
mkdir -p "$DIST_DIR"

# Create virtual environment for building
VENV_DIR="$BUILD_DIR/venv"
if [ ! -d "$VENV_DIR" ]; then
    log "Creating virtual environment..."
    mkdir -p "$BUILD_DIR"
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

# Install PyInstaller in the virtual environment
if ! "$VENV_DIR/bin/pip" show pyinstaller >/dev/null 2>&1; then
    log "Installing PyInstaller in virtual environment..."
    "$VENV_DIR/bin/pip" install pyinstaller || error "Failed to install PyInstaller"
fi

# Create the binary
log "Building binary from update_noti.py..."
"$VENV_DIR/bin/pyinstaller" \
    --onefile \
    --name update-noti \
    --distpath "$DIST_DIR" \
    --workpath "$BUILD_DIR/pyinstaller" \
    --specpath "$BUILD_DIR/pyinstaller" \
    update_noti.py

# Verify binary was created
if [ -f "$DIST_DIR/update-noti" ]; then
    # Test the binary
    log "Testing binary..."
    if "$DIST_DIR/update-noti" --help >/dev/null 2>&1 || [ $? -eq 1 ]; then
        # Exit code 1 is expected since we don't have --help implemented
        log "Binary created successfully!"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}🎉 BUILD COMPLETED! 🎉${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "📦 Binary: $DIST_DIR/update-noti"
        echo -e "📏 Size: $(ls -lh "$DIST_DIR/update-noti" | awk '{print $5}')"
        echo -e "🧪 Test: $DIST_DIR/update-noti"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        error "Binary test failed"
    fi
else
    error "Binary creation failed"
fi

# Clean up build artifacts
log "Cleaning up build artifacts..."
deactivate 2>/dev/null || true
rm -rf "$BUILD_DIR"

log "Build process complete!"