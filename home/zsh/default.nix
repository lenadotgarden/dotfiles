{ pkgs, ... }:

{
  # Désactiver Starship pour revenir au prompt natif style Fish par défaut
  programs.starship.enable = false;

  # FZF pour une autocomplétion et recherche d'historique au sommet (Ctrl+R / Tab)
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    autocd = true;
    history = {
      size = 10000;
      save = 10000;
      share = true;
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
    };
    shellAliases = {
      pbcopy = "wl-copy";
      pbpaste = "wl-paste";
      v = "nvim";
      o = "nvim ~/Garden";
      gay = "agy";
      fsel = "quicklauncher";
      sleep = "systemctl suspend";
      ls = "ls --color=auto";
      grep = "grep --color=auto";
    };
    initContent = ''
      # Activer l'évaluation dynamique des variables dans le prompt (PROMPT_SUBST)
      setopt prompt_subst

      # Charger les séquences de couleurs dynamiques Pywal (Fond d'écran)
      if [[ -f ~/.cache/wal/sequences ]]; then
        cat ~/.cache/wal/sequences 2>/dev/null
      fi

      # Intégration Git légère & propre : Branche entre parenthèses uniquement dans un dépôt Git
      autoload -Uz vcs_info
      zstyle ':vcs_info:git:*' formats ' (%b)'
      zstyle ':vcs_info:*' enable git

      precmd() {
        vcs_info
      }

      # Amélioration du menu d'autocomplétion (sélection au clavier style menu coloré)
      zstyle ':completion:*' menu select
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*'

      # Prompt épuré & élégant aux couleurs du thème : User (Light/Color 7) @ Host (Brightest White/Color 15) | Path (Blue/Color 4) | Git (Yellow/Color 3) | > (Green/Color 2)
      PROMPT='%F{7}%n%f%F{8}@%f%F{15}%m%f %F{4}%~%f%F{3}''${vcs_info_msg_0_}%f %F{2}>%f '

      # Personnalisation des couleurs de saisie (Commandes écrites en blanc très clair / le plus lumineux possible)
      typeset -A ZSH_HIGHLIGHT_STYLES
      ZSH_HIGHLIGHT_STYLES[command]='fg=15,bold'
      ZSH_HIGHLIGHT_STYLES[command-kw]='fg=15,bold'
      ZSH_HIGHLIGHT_STYLES[builtin]='fg=15,bold'
      ZSH_HIGHLIGHT_STYLES[alias]='fg=15,bold'
      ZSH_HIGHLIGHT_STYLES[function]='fg=15,bold'
      ZSH_HIGHLIGHT_STYLES[default]='fg=15'
      ZSH_HIGHLIGHT_STYLES[arg0]='fg=15,bold'

      fastfetch --logo nixos2

      # Read API key from local file if it exists
      if [[ -f ~/.deepseek_api_key ]]; then
        export DEEPSEEK_API_KEY="$(cat ~/.deepseek_api_key)"
      fi

      # Auto-start Hyprland on TTY1 if not already inside a graphical session
      if [[ "$(tty)" == "/dev/tty1" ]] && [[ -z "$WAYLAND_DISPLAY" ]]; then
        exec Hyprland
      fi
    '';
  };

  programs.bash = {
    enable = true;
    initExtra = ''
      unset "Xft.dpi"
      if [[ $- == *i* ]] && [ -z "$NIX_BUILD_TOP" ] && [ -z "$ZSH_VERSION" ]; then
        exec ${pkgs.zsh}/bin/zsh
      fi
    '';
  };
}
