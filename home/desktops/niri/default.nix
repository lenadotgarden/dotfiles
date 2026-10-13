{ config, lib, pkgs, inputs, niriPackage, withXmonad ? false, ... }:

{
  home.packages = with pkgs; [
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.${niriPackage}
  ] ++ lib.optional (niriPackage != "myNiriDms") inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.myNoctalia
  ++ (with pkgs; [
    xwayland-satellite
    swaylock
    swayidle
    kdePackages.dolphin
    swappy
    rofimoji
    rofi
    wtype
  ]);

  services.network-manager-applet.enable = true;
  services.kdeconnect = {
    enable = true;
    indicator = true;
  };

  # When X11 (xMonad) is also installed these must not be global: niri sets
  # XDG_CURRENT_DESKTOP / XDG_SESSION_TYPE itself, and the xmonad module picks DEFAULT_WM.
  home.sessionVariables = lib.mkIf (!withXmonad) {
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_TYPE = "wayland";
    DEFAULT_WM = "niri";
  };
}
