{ config, lib, pkgs, ... }:

{
  home-manager.users.nick = {
    # Source shell functions
    home.file.".zfunctions".source = ../../scripts/shell-functions.sh;

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
          symbol = " ";
          style = "green";
        };
      };
    };
  };
}