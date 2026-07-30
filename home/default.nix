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
    inputs.helium.packages.${pkgs.system}.default
    inputs.handy.packages.${pkgs.system}.default
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
}
