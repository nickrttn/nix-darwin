# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands
- `darwin-rebuild switch` - Build and apply nix-darwin configuration
- `nix flake update` - Update flake dependencies
- `nix-darwin-update` - Custom function to update flakes and rebuild

## Code Style Guidelines
- Follow Nix format style (use nixfmt-rfc-style)
- Use 2-space indentation for .nix files
- Group related configuration settings together
- Prefer declarative configuration over imperative commands
- Use descriptive names for variables and attributes
- Keep sensitive information in 1Password (referenced via op command)
- Follow the existing pattern of organizing configuration by function
- Use lib.concatStrings for multi-line string generation
- Maintain modular configuration between flake.nix and home.nix

## Repository Structure
- flake.nix: Main system configuration (packages, settings)
- home.nix: User environment configuration (dotfiles, programs)
- Both files use shared variables for versions and configuration

## System vs User Configuration

### System Configuration (flake.nix)
- System-wide packages and services
- System preferences and settings
- Hardware configuration
- Network settings
- Global fonts
- Homebrew casks and global apps
- Nix garbage collection settings
- Binary cache configuration
- Security settings

### User Configuration (home.nix)
- User-specific applications
- Dotfiles
- Shell configuration
- Git and development tools
- Programming language environments
- SSH and GPG configuration
- Terminal configuration
- User-specific aliases and functions
- Applications that don't require admin privileges

## Bootstrap Process
1. Install Nix using Determinate Systems installer
2. Install nix-darwin using flakes
3. Clone this repository to /private/etc/nix-darwin
4. Run bootstrap.sh script to set up the environment
5. Run darwin-rebuild switch to apply configuration