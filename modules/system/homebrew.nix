{ config, lib, pkgs, ... }:

{
  homebrew = {
    enable = true;

    caskArgs = {
      appdir = "~/Applications";
      require_sha = true;
    };

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };

    taps = [
      "carvel-dev/carvel"
      "int128/kubelogin"
    ];

    brews = [
      "act"
      "int128/kubelogin/kubelogin"
      "jenv"
    ];

    casks = [
      "orbstack"
      "tableplus"
    ];
  };
}