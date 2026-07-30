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

  # Activer fontconfig pour les polices utilisateur
  fonts.fontconfig.enable = true;

  # Configuration du Thème Sombre Global (GTK + XDG Desktop Portal + Chromium/Helium)
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
    };
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
    inputs.helium.packages.${pkgs.system}.default
    inputs.handy.packages.${pkgs.system}.default
    pkgs.superfile
  ];

  # Fichier Desktop personnalisés (.desktop)
  xdg.desktopEntries.handy = {
    name = "Handy";
    comment = "Offline Speech-to-Text Application";
    exec = "${inputs.handy.packages.${pkgs.system}.default}/bin/handy";
    icon = "handy";
    terminal = false;
    categories = [ "Utility" "AudioVideo" ];
  };

  # Configuration de Superfile (Vim keybindings)
  xdg.configFile."superfile/hotkeys.toml".text = ''
    # Navigation list (Vim motions)
    list_up = ["k", "up"]
    list_down = ["j", "down"]
    page_up = ["ctrl+u", "pgup"]
    page_down = ["ctrl+d", "pgdn"]

    # Panel navigation
    panel_left = ["h", "left"]
    panel_right = ["l", "right"]
  '';

  # Layout Rofi pour wallselect
  xdg.configFile."rofi/wallselect.rasi".source = ../config/rofi/wallselect.rasi;
}
