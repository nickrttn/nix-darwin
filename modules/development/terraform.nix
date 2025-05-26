{ config, lib, pkgs, ... }:

let
  myLib = import ../../lib/default.nix { inherit lib pkgs; };
in
{
  # Terraform through homebrew for version management
  homebrew.brews = [
    "tfenv"
  ];

  # Export terraform version for use in user configuration
  nixpkgs.config.terraform.version = myLib.versions.terraform;
}