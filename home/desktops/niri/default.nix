{ config, pkgs, inputs, ... }:

{
  home.packages = [
    inputs.self.packages.${pkgs.system}.myNiri
  ];

  home.sessionVariables = {
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_TYPE = "wayland";
    DEFAULT_WM = "niri";
  };
}
