{ config, lib, pkgs, ... }:

let
  myLib = import ../lib/default.nix { inherit lib pkgs; };
  
  awsConfigs = {
    "prod-sso" = {
      sso_start_url = "https://d-9267728a52.awsapps.com/start";
      sso_region = "us-west-2";
      sso_account_id = "873097255122";
      sso_role_name = myLib.config.awsProdSsoRole;
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
  home.stateVersion = "23.11";

  # User-specific packages
  home.packages = with pkgs; [
    _1password-cli
    p7zip
  ];

  programs.command-not-found.enable = true;

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

  # Source shell functions
  home.file.".zfunctions".source = ../scripts/shell-functions.sh;

  home.file.".aws/config".text = myLib.mkAwsConfig awsConfigs;

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
        if ! ${pkgs.pyenv}/bin/pyenv versions | grep -q "${myLib.versions.python}"; then
          echo "Installing Python ${myLib.versions.python}..."
          ${pkgs.pyenv}/bin/pyenv install ${myLib.versions.python} -s
        fi
        ${pkgs.pyenv}/bin/pyenv global ${myLib.versions.python}

        # Install and use specific terraform version
        /opt/homebrew/bin/tfenv install ${myLib.versions.terraform}
        /opt/homebrew/bin/tfenv use ${myLib.versions.terraform}
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
              version = myLib.versions.kubectl;
              src = pkgs.fetchFromGitHub {
                owner = "kubernetes";
                repo = "kubernetes";
                rev = "v${myLib.versions.kubectl}";
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
      ${myLib.mkKubeContexts kubeConfigs.clusters}

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
}