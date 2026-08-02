{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hyprland
    ./quickshell
    ./neovim
    ./kitty
    ./fish
    ./git
    ./tmux
    ./fsel
  ];

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

  # Service systemd permanent pour Quickshell
  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell Desktop Bar Service";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "always";
      RestartSec = "2s";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
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
    hyprcursor.enable = true;
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
    inputs.helium.packages.${pkgs.system}.default
    inputs.handy.packages.${pkgs.system}.default
    inputs.yazi.packages.${pkgs.system}.default
    telegram-desktop
    signal-desktop
    karere     # Whatsapp Linux Client
    hypridle   # Sleep mode
    bluetuith  # TUI Bluetooth Manager
    stremio-linux-shell # Stremio Media Player
    clipse # clipboard manager
    cliphist
    wl-clip-persist
  ];

  # Gestionnaire de mise en veille Hypridle
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 300;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
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
    package = inputs.yazi.packages.${pkgs.system}.default;
    enableFishIntegration = true;
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
  xdg.desktopEntries.handy = {
    name = "Handy";
    comment = "Offline Speech-to-Text Application";
    exec = "${inputs.handy.packages.${pkgs.system}.default}/bin/handy";
    icon = "handy";
    terminal = false;
    categories = [ "Utility" "AudioVideo" ];
  };

  # Layout Rofi pour wallselect
  xdg.configFile."rofi/wallselect.rasi".source = ../config/rofi/wallselect.rasi;

  # Configuration du Thème Dynamique de Clipse
  xdg.configFile."clipse/config.json".text = builtins.toJSON {
    useCustom = true;
  };

  xdg.configFile."clipse/custom_theme.json".text = builtins.toJSON {
    useCustom = true;
    TitleFore = "#cdd6f4";
    TitleBack = "#1e1e2e";
    TitleInfo = "#89b4fa";
    NormalTitle = "#cdd6f4";
    DimmedTitle = "#6c7086";
    SelectedTitle = "#cba6f7";
    NormalDesc = "#a6adc8";
    DimmedDesc = "#6c7086";
    SelectedDesc = "#cba6f7";
    StatusMsg = "#a6e3a1";
    PinIndicatorColor = "#f9e2af";
    SelectedBorder = "#cba6f7";
    SelectedDescBorder = "#cba6f7";
    FilteredMatch = "#fab387";
    FilterPrompt = "#a6e3a1";
    FilterInfo = "#89b4fa";
    FilterText = "#cdd6f4";
    FilterCursor = "#f9e2af";
    HelpKey = "#89b4fa";
    HelpDesc = "#a6adc8";
    PageActiveDot = "#cba6f7";
    PageInactiveDot = "#45475a";
    DividerDot = "#cba6f7";
    PreviewedText = "#cdd6f4";
    PreviewBorder = "#cba6f7";
  };
}
