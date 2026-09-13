{ config, pkgs, inputs, ... }:

{
  home.packages = with pkgs; [
    inputs.self.packages.${pkgs.system}.myNiri
    inputs.self.packages.${pkgs.system}.myNoctalia
    xwayland-satellite
    swaylock
    swayidle
    kdePackages.dolphin
  ];

  services.network-manager-applet.enable = true;
  services.kdeconnect = {
    enable = true;
    indicator = true;
  };

  home.sessionVariables = {
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_TYPE = "wayland";
    DEFAULT_WM = "niri";
  };
}
