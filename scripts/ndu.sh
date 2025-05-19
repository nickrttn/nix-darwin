#!/bin/zsh

# Define the ndu function
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