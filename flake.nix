{
  description = "nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    cachix.url = "github:cachix/cachix";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      home-manager,
      cachix,
    }:
    let
      versions = {
        kubectl = "1.29.13";
        python = "3.10.13";
        terraform = "1.1.3";
      };
      config = {
        awsProdSsoRole = "EKS_Access";
      };
      configuration =
        { pkgs, ... }:
        {
          # List packages installed in system profile. To search by name, run:
          # $ nix-env -qaP | grep wget
          environment.systemPackages = with pkgs; [
            awscli2
            bash
            bat
            btop
            cachix
            curl
            eza
            git
            go
            gron
            jq
            kapp
            (kubectl.overrideAttrs (oldAttrs: {
              version = versions.kubectl;
              src = pkgs.fetchFromGitHub {
                owner = "kubernetes";
                repo = "kubernetes";
                rev = "v${versions.kubectl}";
                hash = "sha256-Gcj9YhK/IQEAL/O80bgzLGRMhabs7cTPKLYeUtECNZk=";
              };
            }))
            kubectx
            kubelogin
            kubernetes-helm
            kustomize
            nil
            nixd
            nix-index
            nixfmt-rfc-style
            nodejs_22
            postgresql
            pyenv
            ripgrep
            stern
            vim
            yq
            zsh
          ];

          environment.variables = {
            EDITOR = "zed --wait";
            NODE_PATH = "$HOME/.npm-packages/lib/node_modules";
            PATH = "/Users/nick/.npm-global/bin:$HOME/.local/share/pnpm:$PATH";
            PNPM_HOME = "$HOME/.local/share/pnpm";
            SSH_AUTH_SOCK = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
            VISUAL = "zed --wait";
            ZSH_AUTOSUGGEST_USE_ASYNC = "1";
          };

          environment.pathsToLink = [ "/usr/share/zsh" ];

          # Auto upgrade nix package and the daemon service.
          nix.enable = true;

          # Necessary for using flakes on this system.
          nix.settings.experimental-features = "nix-command flakes";

          # Setup cachix and binary caches for faster builds
          nix.settings = {
            substituters = [
              "https://cache.nixos.org/"
              "https://nix-community.cachix.org"
              "https://nixpkgs-unfree.cachix.org"
            ];
            trusted-public-keys = [
              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
            ];
            trusted-users = [
              "@admin"
              "root"
            ];
            max-jobs = "auto";
            cores = 0;

          };

          # Configure garbage collection
          nix.gc = {
            automatic = true;
            interval = {
              Weekday = 0;
              Hour = 4;
              Minute = 0;
            };
            options = "--delete-older-than 30d";
          };

          # Auto-optimize nix store
          nix.optimise.automatic = true;

          # Setup auto-cleanup for old system generations
          launchd.daemons.nix-cleanup-old-generations = {
            script = ''
              # Keep the last 5 generations, delete older ones
              nix-env --delete-generations old +5

              # Also clean up old home-manager generations
              find /nix/var/nix/profiles/per-user/nick/home-manager* -type l | sort -Vr | tail -n +5 | xargs rm -f || true

              # Finally collect garbage to free up space
              nix-collect-garbage --delete-old
            '';
            serviceConfig = {
              # Run every week, Sunday at 2am
              StartCalendarInterval = [
                {
                  Weekday = 0;
                  Hour = 2;
                  Minute = 0;
                }
              ];
              StandardErrorPath = "/var/log/nix-cleanup.log";
              StandardOutPath = "/var/log/nix-cleanup.log";
            };
          };

          # Set Git commit hash for darwin-version.
          system.configurationRevision = self.rev or self.dirtyRev or null;

          # Used for backwards compatibility, please read the changelog before changing.
          # $ darwin-rebuild changelog
          system.stateVersion = 6;

          system.primaryUser = "nick";

          # Run custom commands after activation
          # system.activationScripts.postActivation.text = ''
          #   echo "Setting npm global prefix..."
          #   ${pkgs.nodejs_20}/bin/npm config set prefix ~/.npm-global
          # '';

          # The platform the configuration will be used on.
          nixpkgs.hostPlatform = "aarch64-darwin";
          nixpkgs.config = {
            allowUnfree = true;
            input-fonts.acceptLicense = true;
          };

          networking.hostName = "Nick-Rutten-MacBook-Pro";
          networking.localHostName = "Nick-Rutten-MacBook-Pro";

          networking.knownNetworkServices = [
            "USB 10/100/1000 LAN"
            "Thunderbolt Bridge"
            "Wi-Fi"
          ];

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
              "tfenv"
            ];

            casks = [
              "orbstack"
              "tableplus"
            ];
          };

          security.pam.services.sudo_local.touchIdAuth = true;

          fonts.packages = [
            pkgs.input-fonts
            pkgs.inter
            pkgs.monaspace
            pkgs.mononoki
          ];

          users.users.nick = {
            name = "nick";
            home = "/Users/nick";
          };

          programs.direnv = {
            enable = true;
            nix-direnv.enable = true;
          };
        };
    in
    {
      # Build darwin flake using:
      # $ darwin-rebuild switch
      darwinConfigurations."Nick-Rutten-MacBook-Pro" = nix-darwin.lib.darwinSystem {
        modules = [
          configuration
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.verbose = true;
            home-manager.backupFileExtension = "backup";
            home-manager.users.nick =
              { pkgs, lib, ... }:
              import ./home.nix {
                inherit
                  config
                  pkgs
                  lib
                  versions
                  ;
              };
          }
        ];
      };

      darwinPackages = self.darwinConfigurations."Nick-Rutten-MacBook-Pro".pkgs;
    };
}
