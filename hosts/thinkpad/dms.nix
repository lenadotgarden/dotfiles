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

  # DMS's power-saver button needs power-profiles-daemon to actually do anything;
  # TLP (which managed this before) is disabled in power.nix to avoid the two
  # fighting over the CPU governor.
  services.power-profiles-daemon.enable = true;
}
