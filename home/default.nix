{ config, pkgs, inputs, ... }:

{
  home.username = "lena";
  home.homeDirectory = "/home/lena";
  home.stateVersion = "25.11";

  # Shell Aliases
  home.shellAliases = {
    fsel = "quicklauncher";
  };

  # Enable fontconfig for user fonts
  fonts.fontconfig.enable = true;

  # Session variables for Apple Silicon / Asahi Hyprland compatibility
  home.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    AQ_NO_MODIFIERS = "1";
  };

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
      name = "Iosevka";
      package = pkgs.iosevka-bin;
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
    fastfetch
    obsidian
    wl-clipboard
    vesktop
    wlsunset
    bitwarden-desktop
    quickshell
    pavucontrol
    pamixer
    inputs.helium.packages.${pkgs.system}.default
    inputs.fsel.packages.${pkgs.system}.default
    (writeShellScriptBin "quicklauncher" ''
      hyprctl dispatch exec "[float; size 1000 650; center]" "kitty --class quicklauncher --name quicklauncher --title fsel -e fsel -d $@"
    '')
  ];

  # Fish Shell Configuration
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting ""
      fastfetch
    '';
  };

  # Tmux Configuration
  programs.tmux = {
    enable = true;
    shortcut = "a";
    baseIndex = 1;
    newSession = true;
    escapeTime = 0;
    historyLimit = 10000;
    terminal = "screen-256color";
  };

  # Bash fallback to auto-exec fish for interactive shells
  programs.bash = {
    enable = true;
    initExtra = ''
      unset "Xft.dpi"
      if [[ $- == *i* ]] && [ -z "$NIX_BUILD_TOP" ] && [ -z "$FISH_VERSION" ]; then
        exec ${pkgs.fish}/bin/fish
      fi
    '';
  };

  # Dotfiles Symlinks (Hyprland, fsel, quickshell, etc.)
  xdg.configFile."hypr/hyprland.conf".source = ../config/hypr/hyprland.conf;
  xdg.configFile."fsel/config.toml".source = ../config/fsel/config.toml;
  xdg.configFile."quickshell/shell.qml".source = ../config/quickshell/shell.qml;
}
