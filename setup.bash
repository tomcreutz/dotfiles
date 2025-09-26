#!/bin/bash

set -e

# ==============================================================================
# 1. INITIAL CHECKS
# ==============================================================================

# Check if the script is run as root. Exit if it is.
if [[ $EUID -eq 0 ]]; then
  echo -e "This script MUST NOT be run as root.\nPlease run it as a regular user. Exiting..." >&2
  exit 1
fi

# Refresh sudo timestamp at the beginning. This prevents repeated password prompts.
echo "Authenticating user for package installation..."
sudo -v
if [[ $? -ne 0 ]]; then
  echo "Failed to authenticate with sudo. Exiting." >&2
  exit 1
fi

# ==============================================================================
# 2. INSTALL REQUIRED SYSTEM TOOLS
# ==============================================================================

echo "Updating system and installing required tools: git, base-devel, rsync, xdg-user-dirs"
sudo pacman -Syu --noconfirm --needed git base-devel rsync xdg-user-dirs | exit 1

pacman -Syyu --noconfirm
pacman -S $(cat pacman_packages)
paru -S $(cat aur_packages)

cp -r .config ~/.config

