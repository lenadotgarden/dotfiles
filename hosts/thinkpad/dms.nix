{ config, lib, pkgs, ... }:

# DankMaterialShell (Wayland shell for niri). Test it from TTY2 with `niri`;
# TTY1 keeps starting xMonad. Niri starts it itself (spawn-at-startup "dms" "run").
{
  programs.dms-shell = {
    enable = true;
    systemd.enable = false; # no systemd graphical session when niri is started from a TTY
  };
}
