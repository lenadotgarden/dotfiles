{ config, pkgs, inputs, ... }:

{
  home.username = "lena";
  home.homeDirectory = "/home/lena";
  home.stateVersion = "25.11";

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # Enable fontconfig for user fonts
  fonts.fontconfig.enable = true;

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
    font = {
      name = "Iosevka Nerd Font";
      package = pkgs.nerd-fonts.iosevka;
    };
    settings = {
      enable_audio_bell = false;
      confirm_os_window_close = 0;
    };
    keybindings = {
      "super+c" = "copy_to_clipboard";
      "super+v" = "paste_from_clipboard";
      "ctrl+shift+c" = "copy_to_clipboard";
      "ctrl+shift+v" = "paste_from_clipboard";
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
    wl-clipboard
    vesktop
    wlsunset
    bitwarden-desktop
    quickshell
    inputs.helium.packages.${pkgs.system}.default
    inputs.fsel.packages.${pkgs.system}.default
    (writeShellScriptBin "quicklauncher" ''
      exec kitty --class quicklauncher -e fsel "$@"
    '')
  ];

  # Dotfiles Symlinks (Hyprland, fsel, quickshell, etc.)
  xdg.configFile."hypr/hyprland.conf".source = ../config/hypr/hyprland.conf;
  xdg.configFile."fsel/config.toml".source = ../config/fsel/config.toml;
  xdg.configFile."quickshell/shell.qml".source = ../config/quickshell/shell.qml;
}
