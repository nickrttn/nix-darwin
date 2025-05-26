{ config, lib, pkgs, ... }:

let
  myLib = import ../../lib/default.nix { inherit lib pkgs; };
in
{
  # System packages for Python development
  environment.systemPackages = with pkgs; [
    pyenv
  ];

  # Export python version for use in user configuration
  nixpkgs.config.python.version = myLib.versions.python;
}