{
  config,
  lib,
  pkgs,
  versions,
  ...
}:

let
  awsConfigs = {
    "prod-sso" = {
      sso_start_url = "https://d-9267728a52.awsapps.com/start";
      sso_region = "us-west-2";
      sso_account_id = "873097255122";
      sso_role_name = config.awsProdSsoRole; # This should be configurable
      region = "us-west-2";
      output = "json";
    };

    "staging-sso" = {
      sso_start_url = "https://d-9267728a52.awsapps.com/start";
      sso_region = "us-west-2";
      sso_account_id = "893894238537";
      sso_role_name = "AdministratorAccess";
      region = "us-west-2";
      output = "json";
    };

    "dev-sso" = {
      sso_start_url = "https://d-9267728a52.awsapps.com/start";
      sso_region = "us-west-2";
      sso_account_id = "361919038798";
      sso_role_name = "AdministratorAccess";
      region = "us-west-2";
      output = "json";
    };
  };

  kubeConfigs = {
    clusters = {
      "dev-us-east-1-main" = {
        profile = "dev-sso";
        region = "us-east-1";
        name = "dev-us-east-1-main";
      };
      "eks-staging" = {
        profile = "staging-sso";
        region = "us-west-2";
        name = "eks-staging";
      };
      "eks-prod" = {
        profile = "prod-sso";
        region = "us-west-2";
        name = "eks-prod";
      };
      "eks-prod-eu" = {
        profile = "prod-sso";
        region = "eu-west-1";
        name = "eks-prod-eu";
      };
    };
  };

in
{
  home.enableNixpkgsReleaseCheck = true;

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "nick";
  home.homeDirectory = "/Users/nick";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.11"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    _1password-cli
    p7zip
  ];

  # Source shell functions
  home.file.".zfunctions".source = ./scripts/shell-functions.sh;

  home.file.".aws/config".text = lib.concatStrings (
    lib.mapAttrsToList (name: cfg: ''
      [profile ${name}]
      sso_start_url = ${cfg.sso_start_url}
      sso_region = ${cfg.sso_region}
      sso_account_id = ${cfg.sso_account_id}
      sso_role_name = ${cfg.sso_role_name}
      region = ${cfg.region}
      output = ${cfg.output}

    '') awsConfigs
  );

  # Python environment management
  programs.pyenv = {
    enable = true;
    enableZshIntegration = true;
  };

  home.activation = {
    postInstall =
      let
        path = lib.makeBinPath (
          with pkgs;
          [
            coreutils
            curl
            gawk
            gnutar
            unzip
            which
          ]
        );
      in
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export PATH="${path}:$PATH"

        echo "Running post-installation setup..."

        # homebrew
        eval "$(/opt/homebrew/bin/brew shellenv)"

        # Install python version
        if ! ${pkgs.pyenv}/bin/pyenv versions | grep -q "${versions.python}"; then
          echo "Installing Python ${versions.python}..."
          ${pkgs.pyenv}/bin/pyenv install ${versions.python} -s
        fi
        ${pkgs.pyenv}/bin/pyenv global ${versions.python}

        # Install and use specific terraform version
        /opt/homebrew/bin/tfenv install ${versions.terraform}
        /opt/homebrew/bin/tfenv use ${versions.terraform}
      '';

    setupKubernetesAccess = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="${
        lib.makeBinPath (
          with pkgs;
          [
            _1password-cli
            awscli2
            coreutils
            gnused
            (kubectl.overrideAttrs (oldAttrs: {
              version = versions.kubectl;
              src = pkgs.fetchFromGitHub {
                owner = "kubernetes";
                repo = "kubernetes";
                rev = "v${versions.kubectl}";
                hash = "sha256-Gcj9YhK/IQEAL/O80bgzLGRMhabs7cTPKLYeUtECNZk=";
              };
            }))
          ]
        )
      }:$PATH"

      # Sign in to 1Password
      eval $(op signin --account superblocks)

      # Log in to AWS SSO if needed
      aws sts get-caller-identity &> /dev/null
      EXIT_CODE="$?"
      if [ "$EXIT_CODE" -ne 0 ]; then
        aws sso login --profile "staging-sso"
      fi

      # Setup kubernetes contexts
      ${lib.concatStrings (
        lib.mapAttrsToList (name: cluster: ''
          aws eks --profile "${cluster.profile}" --region "${cluster.region}" \
            update-kubeconfig --name "${cluster.name}" || true
        '') kubeConfigs.clusters
      )}

      # Configure OIDC authentication
      kubectl config set-credentials oidc \
        --exec-api-version=client.authentication.k8s.io/v1beta1 \
        --exec-command=kubectl \
        --exec-arg=oidc-login \
        --exec-arg=--listen-address="127.0.0.1:18000" \
        --exec-arg=get-token \
        --exec-arg=--oidc-issuer-url="$(op item get AWS_EKS_STAGING_OIDC_ISSUER_URL --fields 'notesPlain')" \
        --exec-arg=--oidc-client-id="$(op item get AWS_EKS_STAGING_OIDC_CLIENT_ID --fields 'notesPlain')" \
        --exec-arg=--oidc-extra-scope="email offline_access profile openid"

      # Delete and recreate contexts
      ${lib.concatStrings (
        lib.mapAttrsToList (name: cluster: ''
          kubectl config delete-context "arn:aws:eks:${cluster.region}:${cluster.profile}:cluster/${cluster.name}" || true
          kubectl config set-context "${name}" \
            --cluster="arn:aws:eks:${cluster.region}:${cluster.profile}:cluster/${cluster.name}" \
            --user="oidc"
        '') kubeConfigs.clusters
      )}

      # Set default context
      kubectl config use-context "eks-staging"
    '';
  };

  programs.command-not-found.enable = true;

  programs.zsh = {
    enable = true;
    enableVteIntegration = true;

    autocd = true;
    autosuggestion.enable = true;

    shellAliases = {
      gbsc = "git branch --sort=-committerdate";
      hm = "home-manager";
      ls = "eza";
      lst = "eza --tree --level 2";
      pnpm = "corepack pnpm";
      gac = "git add -A && git commit -m";
    };

    historySubstringSearch = {
      enable = true;
    };

    plugins =
      [
        {
          name = "fast-syntax-highlighting";
          file = "share/zsh/site-functions/fast-syntax-highlighting.plugin.zsh";
          src = pkgs.zsh-fast-syntax-highlighting;
        }
        {
          name = "zsh-you-should-use";
          src = pkgs.zsh-you-should-use;
          file = "share/zsh/plugins/you-should-use/you-should-use.plugin.zsh";
        }
        {
          name = "prezto";
          file = "share/zsh-prezto/modules/git/alias.zsh";
          src = pkgs.zsh-prezto;
        }
        {
          name = "zsh-safe-rm";
          src = pkgs.fetchFromGitHub {
            owner = "mattmc3";
            repo = "zsh-safe-rm";
            rev = "6ab18fdfeeb41f2927c88715dcb8be2f936eaf30";
            sha256 = "sha256-1W8TdtcuksELl9L/lnKFPWdw27TBgYJBfNcrBivJuqI=";
            fetchSubmodules = true;
          };
        }
      ]
      ++ builtins.map
        (x: {
          name = "zephyr/" + x;
          file = "plugins/" + x + "/" + x + ".plugin.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "mattmc3";
            repo = "zephyr";
            rev = "18d86e87054b040fa4fe80d1553b4e2a8763369f";
            sha256 = "sha256-uE+o4Y4ntPlD8g8QCmk4GOSeb6ejXlhTfDyqM0QZFDA=";
          };
        })
        [
          "environment"
          "history"
          "directory"
          "color"
          "utility"
          "completion"
        ];

    initContent = ''
      if [[ "$TERM_PROGRAM" = ghostty ]]; then
          if [[ -n "$GHOSTTY_RESOURCES_DIR" ]]; then
              source "$GHOSTTY_RESOURCES_DIR"/shell-integration/zsh/ghostty-integration
          fi
          if [[ -n "$GHOSTTY_BIN_DIR" &&  :"$PATH": != *:"$GHOSTTY_BIN_DIR":* ]]; then
              PATH=$GHOSTTY_BIN_DIR''${PATH:+:$PATH}
          fi
      fi

      # This is handled by home-manager's pyenv integration

      # jenv
      export PATH="$HOME/.jenv/bin:$PATH"
      eval "$(jenv init -)"

      # Source shell functions
      if [[ -f "$HOME/.zfunctions" ]]; then
          source "$HOME/.zfunctions"
      fi
    '';
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      format = "$character";
      command_timeout = 2000;
      right_format = lib.concatStrings [
        "$git_branch"
        "$git_commit"
        "$git_state"
        "$git_status"
        "$directory"
        "$hostname"
        "$line_break"
        "$status"
      ];
      character = {
        success_symbol = "[λ](green)";
        error_symbol = "[λ](red)";
      };
      directory = {
        truncation_length = 2;
        style = "fg:242";
      };
      git_branch = {
        format = "[$symbol$branch]($style) ";
        symbol = " ";
        style = "green";
      };
    };
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper = {
      enable = true;
    };
    settings = {
      editor = "zed --wait";
      aliases = {
        co = "pr checkout";
        pv = "pr view";
      };
    };
  };

  programs.git = {
    enable = true;
    package = pkgs.git;
    userName = "Nick Rutten";
    userEmail = "2504906+nickrttn@users.noreply.github.com";
    signing = {
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOS0QW/DM0KBNXXe3spOqeWZm6rErsyayYSh4jSUnIX7";
      signByDefault = true;
    };
    difftastic = {
      enable = true;
    };
    extraConfig = {
      core = {
        autocrlf = "input";
        editor = "zed --wait";
      };
      init = {
        defaultBranch = "main";
      };
      push = {
        autoSetupRemote = true;
      };
      commit = {
        gpgsign = true;
      };
      gpg = {
        format = "ssh";
        ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      };
      color = {
        ui = true;
      };
    };
    lfs = {
      enable = true;
    };
  };

  programs.gpg = {
    enable = true;
    settings = {
      auto-key-retrieve = true;
      no-emit-version = true;
      default-key = "8076DC1A752E9DCC9CB6DA51D206224E62BA642E";
    };
  };
}
