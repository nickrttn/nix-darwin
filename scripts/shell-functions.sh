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

# Function to update nix-darwin and show the diff between profiles
ndu() {
  # Change to nix-darwin directory
  pushd /private/etc/nix-darwin

  # Get the current system profile generation number
  local current_gen=$(readlink /nix/var/nix/profiles/system | sed -E 's/system-([0-9]+)-link/\1/')
  local old_profile="/nix/var/nix/profiles/system-$current_gen-link"

  echo "Updating nix flake..."
  if ! nix flake update; then
    echo "Error updating nix flake. Aborting."
    popd
    return 1
  fi

  echo "Rebuilding darwin configuration..."
  # This is the only part that needs sudo
  sudo darwin-rebuild switch

  # Get the new system profile generation number
  local new_gen=$(readlink /nix/var/nix/profiles/system | sed -E 's/system-([0-9]+)-link/\1/')
  local new_profile="/nix/var/nix/profiles/system-$new_gen-link"

  if [ "$old_profile" != "$new_profile" ]; then
    echo "Comparing profiles: $old_profile -> $new_profile"
    # Store the diff output to avoid broken pipe issues
    local diff_output=$(nix store diff-closures "$old_profile" "$new_profile")
    # Check if there are actual differences
    if echo "$diff_output" | grep -q "╰─ "; then
      echo "$diff_output"
    else
      echo "No substantive changes between immediate profiles. Searching for first meaningful diff..."
      # Search backwards through older generations until we find a diff with changes
      local found_diff=false
      for ((prev_gen=current_gen-1; prev_gen>0; prev_gen--)); do
        local prev_profile="/nix/var/nix/profiles/system-$prev_gen-link"
        if [ -e "$prev_profile" ]; then
          echo "Comparing with older profile: $prev_profile -> $new_profile"
          # Store the diff output to avoid broken pipe issues
          local prev_diff_output=$(nix store diff-closures "$prev_profile" "$new_profile")
          if echo "$prev_diff_output" | grep -q "→"; then
            echo "$prev_diff_output"
            found_diff=true
            break
          fi
        fi
        # Stop after checking 5 previous generations to avoid excessive searching
        if ((current_gen - prev_gen >= 5)); then
          break
        fi
      done
      if [ "$found_diff" = false ]; then
        echo "No significant changes found in last 5 generations."
      fi
    fi
  else
    echo "No changes in system profile."
  fi

  # Return to original directory
  popd
  return 0
}
