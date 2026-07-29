{ config, pkgs, inputs, ... }:

{
  home.username = "lena";
  home.homeDirectory = "/home/lena";
  home.stateVersion = "25.11";

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Git Configuration
  programs.git = {
    enable = true;
    settings = {
      user.name = "lena";
      user.email = "lena@example.com"; # Modifier avec votre email Git
      init.defaultBranch = "main";
    };
  };

  # Kitty Terminal Configuration
  programs.kitty = {
    enable = true;
    settings = {
      enable_audio_bell = false;
      confirm_os_window_close = 0;
    };
  };

  # Neovim Configuration
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;
  };

  # User Packages
  home.packages = with pkgs; [
    obsidian
    wofi
    wl-clipboard
    vesktop
    wlsunset
    inputs.helium.packages.${pkgs.system}.default
  ];

  # Dotfiles Symlinks (Hyprland, etc.)
  xdg.configFile."hypr/hyprland.conf".source = ../config/hypr/hyprland.conf;
}
