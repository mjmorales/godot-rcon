#!/bin/bash

# Godot RCON Addon Installer
# This script installs the godot-rcon addon into a Godot project

set -e

ADDON_NAME="godot_rcon"
ADDON_URL="https://github.com/mjmorales/godot-rcon/archive/refs/heads/main.tar.gz"
TEMP_DIR=$(mktemp -d)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if we're in a Godot project directory
if [ ! -f "project.godot" ]; then
    echo -e "${RED}Error: No project.godot found in current directory.${NC}"
    echo "Please run this script from the root of your Godot project."
    exit 1
fi

# Create addons directory if it doesn't exist
if [ ! -d "addons" ]; then
    echo "Creating addons directory..."
    mkdir -p addons
fi

# Check if addon already exists
if [ -d "addons/${ADDON_NAME}" ]; then
    echo -e "${YELLOW}Warning: ${ADDON_NAME} already exists in addons directory.${NC}"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    rm -rf "addons/${ADDON_NAME}"
fi

# Download and extract addon
echo "Downloading godot-rcon addon..."
cd "$TEMP_DIR"

# Try to download from GitHub
if command -v curl &> /dev/null; then
    curl -L "$ADDON_URL" -o addon.tar.gz
elif command -v wget &> /dev/null; then
    wget "$ADDON_URL" -O addon.tar.gz
else
    echo -e "${RED}Error: Neither curl nor wget is available.${NC}"
    echo "Please install curl or wget and try again."
    exit 1
fi

# Extract the archive
echo "Extracting addon..."
tar -xzf addon.tar.gz

# Find the addon directory in the extracted content
EXTRACTED_DIR=$(find . -name "godot-rcon-*" -type d | head -n 1)

# Copy addon to project
echo "Installing addon to project..."
cd - > /dev/null
cp -r "$TEMP_DIR/$EXTRACTED_DIR/addons/${ADDON_NAME}" "addons/"

# Clean up
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✓ godot-rcon addon installed successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Open your project in Godot"
echo "2. Go to Project → Project Settings → Plugins"
echo "3. Enable the 'Godot RCON' plugin"
echo ""
echo "For more information, visit: https://github.com/mjmorales/godot-rcon"