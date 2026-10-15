{ config, lib, pkgs, inputs, niriPackage, withXmonad ? false, ... }:

let
  gsettingsSchemaDir = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";
in
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
    # Electron apps (Vesktop, Signal, Element) default to XWayland via xwayland-satellite,
    # which has a known caps-lock sync bug (niri#4600, not niri's fault - fixed upstream by
    # running natively on Wayland instead). nixpkgs' Electron wrapper only adds the Wayland
    # ozone flags when both this and WAYLAND_DISPLAY are set, so it's a no-op under xMonad/X11.
    NIXOS_OZONE_WL = "1";
    # Shell-level only (goes to ~/.zshenv via hm-session-vars.sh) — doesn't reach
    # systemd --user or dbus-activated services. See xdg.configFile below for that.
    GSETTINGS_SCHEMA_DIR = gsettingsSchemaDir;
  } // lib.optionalAttrs (!withXmonad) {
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_TYPE = "wayland";
  };

  # This nixpkgs installs gsettings-desktop-schemas under its own
  # share/gsettings-schemas/<name>/glib-2.0/schemas (collision-avoidance layout)
  # instead of the shared share/glib-2.0/schemas pathsToLink expects, so GIO can't
  # find it via any profile. home.sessionVariables doesn't reach systemd --user
  # (it only lands in shell init files) — a real ~/.config/environment.d/*.conf
  # file is what systemd --user reads natively at session start, which is how
  # dbus-activated xdg-desktop-portal-gtk resolves color-scheme for
  # Chromium/Helium's dark/light mode query.
  xdg.configFile."environment.d/90-gsettings-schema-dir.conf".text = ''
    GSETTINGS_SCHEMA_DIR=${gsettingsSchemaDir}
    # Belt-and-suspenders for xdg-desktop-portal-gtk: without WAYLAND_DISPLAY (see
    # the niri spawn-at-startup import) GTK3 tries X11 and fails with "cannot open
    # display". Forcing the backend here means it doesn't matter which env var
    # races in first.
    GDK_BACKEND=wayland
  '';

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
