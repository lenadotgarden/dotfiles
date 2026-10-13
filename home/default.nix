{ config, lib, pkgs, inputs, withHandy, withFsel, withFlakeYazi, withNiri, withXmonad, ... }:

let
  # yazi from its flake (master, compiled from source) or the cached nixpkgs build
  yaziPkg = if withFlakeYazi then inputs.yazi.packages.${pkgs.stdenv.hostPlatform.system}.default else pkgs.yazi;
in
{
  imports = [
    # --- Desktop Environment ---
    # (niri / xmonad are added below, per host)
    # ---------------------------

    ./neovim
    ./kitty
    ./zsh
    ./git
    ./tmux
    ./librewolf
  ]
  # fsel is built with naersk (one derivation per Rust crate): heavy to build
  ++ lib.optional withFsel ./fsel
  ++ lib.optional withNiri ./desktops/niri
  ++ lib.optional withXmonad ./desktops/xmonad;

  home.username = "lena";
  home.homeDirectory = "/home/lena";
  home.stateVersion = "25.11";

  # Raccourcis shell globaux
  home.shellAliases = {
    v = "nvim";
    gay = "agy";
    fsel = "quicklauncher";
    sleep = "systemctl suspend";
  };

  # Services systemd permanents pour le presse-papier universel (cliphist + clipse)
  systemd.user.services.cliphist = {
    Unit = {
      Description = "Cliphist Clipboard Watcher Service";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "always";
      RestartSec = "2s";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.clipse = {
    Unit = {
      Description = "Clipse Listener Service";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Environment = [
        "WAYLAND_DISPLAY=wayland-1"
        "XDG_RUNTIME_DIR=/run/user/1000"
      ];
      ExecStart = "${pkgs.clipse}/bin/clipse -listen";
      Restart = "always";
      RestartSec = "2s";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Activer fontconfig pour les polices utilisateur
  fonts.fontconfig.enable = true;

  # Configuration du Thème Sombre Global (GTK + XDG Desktop Portal + Chromium/Helium)
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
    };
  };

  # Configuration du thème de curseur style macOS
  home.pointerCursor = {
    enable = true;
    name = "macOS";
    package = pkgs.apple-cursor;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    gtk4.theme = null;
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  # Applications et outils utilisateur
  home.packages = with pkgs; [
    fastfetch
    obsidian
    wl-clipboard
    vesktop
    wlsunset
    bitwarden-desktop
    pavucontrol
    pamixer
    wtype
    pywal
    awww
    hyprpicker
    libnotify
    rofi
    jq
    imagemagick
    brightnessctl
    playerctl
    inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default
    yaziPkg
    telegram-desktop
    signal-desktop
    karere     # Whatsapp Linux Client
    hypridle   # Sleep mode
    bluetuith  # TUI Bluetooth Manager
    stremio-linux-shell # Stremio Media Player
    clipse # clipboard manager
    cliphist
    wl-clip-persist
    anki
    btop
    flameshot
    grim
    slurp
    element-desktop
    thunderbird
    qutebrowser
    claude-code
  ]
  # Handy (speech-to-text) is heavy to build: thousands of Rust/npm derivations
  ++ lib.optional withHandy inputs.handy.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Gestionnaire de mise en veille Hypridle avec économie d'énergie écran
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "niri msg action power-on-monitors";
      };
      listener = [
        {
          timeout = 150;
          on-timeout = "brightnessctl -s set 10%";
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 300;
          on-timeout = "niri msg action power-off-monitors";
          on-resume = "niri msg action power-on-monitors";
        }
        {
          timeout = 600;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };

  # Configuration Yazi (Explorateur de fichiers par défaut)
  programs.yazi = {
    enable = true;
    package = yaziPkg;
    enableZshIntegration = true;
    enableBashIntegration = true;
    shellWrapperName = "y";
    settings = {
      opener = {
        edit = [
          { run = ''nvim "%1"''; block = true; for = "unix"; }
        ];
      };
      open = {
        rules = [
          { mime = "*"; use = [ "edit" "open" ]; }
        ];
      };
    };
  };

  # Définir Yazi & Neovim comme éditeur et gestionnaire par défaut
  home.sessionVariables = {
    FILEMANAGER = "yazi";
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # Fichier Desktop personnalisés (.desktop)
  xdg.desktopEntries = {
    btop = {
      name = "btop";
      comment = "Resource Monitor";
      exec = "kitty -e btop";
      icon = "btop";
      terminal = false;
      categories = [ "System" "Monitor" ];
    };
  } // lib.optionalAttrs withHandy {
    handy = {
      name = "Handy";
      comment = "Offline Speech-to-Text Application";
      exec = "${inputs.handy.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/handy";
      icon = "handy";
      terminal = false;
      categories = [ "Utility" "AudioVideo" ];
    };
  };

  # Layout Rofi pour wallselect
  xdg.configFile."rofi/wallselect.rasi".source = ../config/rofi/wallselect.rasi;

  # Configuration du Thème Dynamique de Clipse
  xdg.configFile."clipse/config.json".text = builtins.toJSON {
    useCustom = true;
  };

  xdg.configFile."wal/templates/clipse-theme.json".text = builtins.toJSON {
    useCustom = true;
    TitleFore = "{color15}";
    TitleBack = "{background}";
    TitleInfo = "{color4}";
    NormalTitle = "{color15}";
    DimmedTitle = "{color8}";
    SelectedTitle = "{color6}";
    NormalDesc = "{color7}";
    DimmedDesc = "{color8}";
    SelectedDesc = "{color6}";
    StatusMsg = "{color2}";
    PinIndicatorColor = "{color3}";
    SelectedBorder = "{color6}";
    SelectedDescBorder = "{color6}";
    FilteredMatch = "{color1}";
    FilterPrompt = "{color2}";
    FilterInfo = "{color4}";
    FilterText = "{color15}";
    FilterCursor = "{color3}";
    HelpKey = "{color4}";
    HelpDesc = "{color7}";
    PageActiveDot = "{color6}";
    PageInactiveDot = "{color8}";
    DividerDot = "{color6}";
    PreviewedText = "{color15}";
    PreviewBorder = "{color6}";
  };

  xdg.configFile."clipse/custom_theme.json".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.cache/wal/clipse-theme.json";
}
