#!/bin/bash
set -e

# Bootstrap script for nix-darwin setup
# This script will set up a complete macOS development environment with nix-darwin

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print color message
msg() {
  echo -e "${BLUE}==>${NC} $1"
}

success() {
  echo -e "${GREEN}✓${NC} $1"
}

warn() {
  echo -e "${YELLOW}!${NC} $1"
}

error() {
  echo -e "${RED}✗${NC} $1"
}

# Check if we're running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
  error "This script is for macOS only!"
  exit 1
fi

# Step 1: Install Nix if not already installed
msg "Checking for Nix installation..."
if ! command -v nix &>/dev/null; then
  msg "Installing Nix using Determinate Systems installer..."
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
  
  # Source nix 
  if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
  fi
  success "Nix installed"
else
  success "Nix already installed"
fi

# Step 2: Install nix-darwin if not already installed
msg "Checking for nix-darwin..."
if ! command -v darwin-rebuild &>/dev/null; then
  msg "Installing nix-darwin..."
  sudo nix run nix-darwin/master#darwin-rebuild -- switch
  success "nix-darwin installed"
else
  success "nix-darwin already installed"
fi

# Step 3: Check if the nix-darwin configuration already exists
msg "Checking for existing nix-darwin configuration..."
DARWIN_CONFIG_DIR="/private/etc/nix-darwin"

if [ -d "$DARWIN_CONFIG_DIR" ] && [ -f "$DARWIN_CONFIG_DIR/flake.nix" ]; then
  success "nix-darwin configuration already exists at $DARWIN_CONFIG_DIR"
else
  error "nix-darwin configuration not found at $DARWIN_CONFIG_DIR"
  msg "Please ensure configuration exists before proceeding"
  exit 1
fi

# Step 4: Build the nix-darwin configuration
msg "Building nix-darwin configuration..."
cd "$DARWIN_CONFIG_DIR"

# Check if we have a lock file already
if [ -f "flake.lock" ]; then
  msg "Using existing flake.lock (faster rebuild)"
else
  msg "No flake.lock found, will be created during build"
fi

# Build the configuration
darwin-rebuild switch
success "nix-darwin built and activated"

# Step 5: Remind to restart shell
msg "Setup complete! Please restart your shell or run:"
echo "  exec \$SHELL"

# Final success message
success "Your macOS development environment is now set up!"
echo ""
echo "You can update your system anytime with:"
echo "  nix-darwin-update"