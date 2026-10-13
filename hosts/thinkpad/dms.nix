{ config, lib, pkgs, inputs, ... }:

# DankMaterialShell (Wayland shell for niri). Niri starts it itself (spawn-at-startup "dms" "run").
{
  programs.dms-shell = {
    enable = true;
    package = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default; # upstream, newer than nixpkgs
    enableSystemMonitoring = true;
    enableDynamicTheming = true; # wallpaper-based colours
    systemd.enable = false; # no systemd graphical session when niri is started from a TTY
  };

  # DMS turns on power-profiles-daemon, which conflicts with TLP (see power.nix)
  services.power-profiles-daemon.enable = lib.mkForce false;
}
