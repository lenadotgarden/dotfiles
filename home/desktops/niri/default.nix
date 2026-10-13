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

  # niri is the default session on TTY1. When X11 (xMonad) is also installed, only
  # DEFAULT_WM is global: niri sets XDG_CURRENT_DESKTOP / XDG_SESSION_TYPE itself,
  # and exporting them would break X11 apps. xMonad: log in on TTY2 and run `startx`.
  home.sessionVariables = {
    DEFAULT_WM = "niri";
  } // lib.optionalAttrs (!withXmonad) {
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_TYPE = "wayland";
  };

  # DMS rewrites settings.json itself whenever its settings UI is used, so it can't be a
  # read-only xdg.configFile symlink. Seed it once from the repo; re-copy the live file
  # here manually whenever you want to snapshot further tweaks.
  home.activation = lib.mkIf (niriPackage == "myNiriDms") {
    seedDmsSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      DMS_SETTINGS="$HOME/.config/DankMaterialShell/settings.json"
      if [ ! -e "$DMS_SETTINGS" ]; then
        run mkdir -p "$(dirname "$DMS_SETTINGS")"
        run install -m 644 "${./dms-settings.json}" "$DMS_SETTINGS"
      fi
    '';
  };
}
