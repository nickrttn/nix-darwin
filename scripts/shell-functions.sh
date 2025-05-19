#!/bin/bash

# Shell functions for common development workflows
# Source this file from your shell, or add these functions to your ~/.zshrc

# Create a new directory and enter it
mkcd() {
  mkdir -p "$@" && cd "$@"
}

# Extract most archive types with a single command
extract() {
  if [ -f "$1" ] ; then
    case "$1" in
      *.tar.bz2)   tar xjf "$1"     ;;
      *.tar.gz)    tar xzf "$1"     ;;
      *.bz2)       bunzip2 "$1"     ;;
      *.rar)       unrar e "$1"     ;;
      *.gz)        gunzip "$1"      ;;
      *.tar)       tar xf "$1"      ;;
      *.tbz2)      tar xjf "$1"     ;;
      *.tgz)       tar xzf "$1"     ;;
      *.zip)       unzip "$1"       ;;
      *.Z)         uncompress "$1"  ;;
      *.7z)        7z x "$1"        ;;
      *)           echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# Run a command in each subdirectory
inall() {
  for dir in */; do
    echo "Executing in $dir"
    (cd "$dir" && $@)
  done
}

# Get the code for an HTTP status code
http_code() {
  curl -s -o /dev/null -w "%{http_code}" "$1"
}

# Quickly search for a process
psg() {
  ps aux | grep -v grep | grep -i -e VSZ -e "$@"
}

# Quickly find files by name
ff() {
  find . -type f -name "*$@*"
}

# Copy the contents of a file to clipboard
clip() {
  cat "$1" | pbcopy
}

# Print the PATH, one entry per line
path() {
  echo $PATH | tr ":" "\n"
}

# Quickly check which AWS profile is active
aws_profile() {
  echo "AWS_PROFILE: ${AWS_PROFILE:-not set}"
  aws sts get-caller-identity 2>/dev/null || echo "Not authenticated with AWS"
}

# Fully clean nix store, removing old generations and optimizing
nix_full_clean() {
  echo "Collecting garbage..."
  nix-collect-garbage -d
  echo "Optimizing store..."
  nix-store --optimize
  echo "Done."
}

# Find the process using a specific port
port() {
  lsof -i :"$1"
}

# Run a simple HTTP server in the current directory
serve() {
  local port="${1:-8000}"
  python -m http.server "$port"
}

# Create a timestamped backup of a file
backup() {
  cp "$1" "$1.$(date +%Y%m%d-%H%M%S).backup"
}
