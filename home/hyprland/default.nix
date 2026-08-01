{ config, pkgs, inputs, ... }:

let
  theme = import ../theme.nix;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";
    extraConfig = builtins.readFile ../../config/hypr/hyprland.conf;
  };

  # Lier directement le fichier dans ~/.config/hypr/hyprland.conf pour rechargement chaud
  xdg.configFile."hypr/hyprland.conf".source = ../../config/hypr/hyprland.conf;

  # Session variables pour Apple Silicon (Asahi NixOS) + Curseur macOS
  home.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    AQ_NO_MODIFIERS = "1";
    XCURSOR_THEME = "macOS";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_THEME = "macOS";
    HYPRCURSOR_SIZE = "24";
  };
}
