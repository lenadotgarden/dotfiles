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
    fsel = "quicklauncher";
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
    yazi
    telegram-desktop
    signal-desktop
    karere
  ];

  # Configuration Yazi (Explorateur de fichiers par défaut)
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    enableBashIntegration = true;
    shellWrapperName = "y";
    theme = {
      flavor = {
        use = "catppuccin-mocha";
      };
    };
  };

  # Définir Yazi / Terminal File Manager comme gestionnaire par défaut
  home.sessionVariables = {
    FILEMANAGER = "yazi";
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
}
