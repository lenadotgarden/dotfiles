{ pkgs, ... }:

{
  # Désactiver Starship pour revenir au prompt natif style Fish par défaut
  programs.starship.enable = false;

  # FZF pour une autocomplétion et recherche d'historique au sommet (Ctrl+R / Tab)
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    # indices ANSI (-1 = couleur par défaut du terminal) : suit la palette Noctalia
    colors = {
      fg = "-1"; bg = "-1"; hl = "4";
      "fg+" = "-1"; "bg+" = "0"; "hl+" = "12";
      info = "3"; prompt = "2"; pointer = "5"; marker = "2"; spinner = "3"; header = "8";
    };
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
      # Charger nvm (gère les versions de Node, et expose les binaires npm globaux comme `claude`)
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

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

      # Prompt épuré & élégant aux couleurs du thème : User @ Host (couleur de texte par défaut du terminal, s'adapte aux thèmes clair/sombre) | Path (Blue/Color 4) | Git (Yellow/Color 3) | > (Green/Color 2)
      PROMPT='%n%F{8}@%f%m %F{4}%~%f%F{3}''${vcs_info_msg_0_}%f %F{2}>%f '

      # Personnalisation des couleurs de saisie (gras, sans forcer de couleur : suit la couleur de texte par défaut du terminal donc s'adapte aux thèmes clair/sombre)
      # Couleurs ANSI uniquement (0-15) : elles viennent de la palette du terminal, donc de Noctalia
      # (ghostty). Le prompt, la coloration, les suggestions et fzf changent avec le thème du bureau.
      ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
      typeset -A ZSH_HIGHLIGHT_STYLES
      ZSH_HIGHLIGHT_STYLES[command]='fg=2,bold'
      ZSH_HIGHLIGHT_STYLES[command-kw]='fg=5,bold'
      ZSH_HIGHLIGHT_STYLES[builtin]='fg=2,bold'
      ZSH_HIGHLIGHT_STYLES[alias]='fg=2,bold'
      ZSH_HIGHLIGHT_STYLES[function]='fg=2,bold'
      ZSH_HIGHLIGHT_STYLES[arg0]='fg=2,bold'
      ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=1'
      ZSH_HIGHLIGHT_STYLES[path]='fg=4,underline'
      ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=3'
      ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=3'
      ZSH_HIGHLIGHT_STYLES[comment]='fg=8'

      fastfetch --logo nixos2

      # Read API key from local file if it exists
      if [[ -f ~/.deepseek_api_key ]]; then
        export DEEPSEEK_API_KEY="$(cat ~/.deepseek_api_key)"
      fi

      # Auto-start WM on TTY1 if not already inside a graphical session
      if [[ "$(tty)" == "/dev/tty1" ]] && [[ -z "$WAYLAND_DISPLAY" ]] && [[ -z "$DISPLAY" ]]; then
        case "''${DEFAULT_WM:-niri}" in
          # no exec: if X dies you get a shell instead of an autologin respawn loop
          xmonad) startx ;;
          # niri-session (not bare niri) so niri.service activates graphical-session.target;
          # without it xdg-desktop-portal won't start and apps can't read light/dark.
          niri) exec niri-session ;;
          # sway / mango : pas de exec. Si le compositeur plante au démarrage, on garde un shell
          # (au lieu d'une boucle d'autologin) et l'erreur est dans ~/.cache/wm-session.log.
          *)
            mkdir -p ~/.cache
            ''${DEFAULT_WM:-niri} 2> ~/.cache/wm-session.log
            echo "''${DEFAULT_WM:-niri} s'est arrêté (code $?). Journal : ~/.cache/wm-session.log"
            ;;
        esac
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
