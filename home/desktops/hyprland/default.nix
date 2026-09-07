{ config, pkgs, ... }:

{
  imports = [
    ../../hyprland
    ../../quickshell
  ];

  home.sessionVariables = {
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
    DEFAULT_WM = "Hyprland";
  };
}
