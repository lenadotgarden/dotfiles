{ config, lib, pkgs, inputs, ... }:

# Dux Shell, formerly DankMaterialShell/DMS (Wayland shell for niri). Niri starts it itself
# (spawn-at-startup "dms" "run"). `programs.dms-shell` here is nixpkgs' own module
# (nixos/modules/programs/wayland/dms-shell.nix), not upstream's `programs.dank-material-shell` -
# the `package` override below pulls the newer upstream build; nixpkgs' module options lag
# behind separately (as of 2026-10, system monitoring + matugen dynamic theming are both
# built-in now and their enable* options were removed - don't re-add them).
{
  programs.dms-shell = {
    enable = true;
    package = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default; # upstream, newer than nixpkgs
    systemd.enable = false; # no systemd graphical session when niri is started from a TTY
  };

  # DMS's power-saver button needs power-profiles-daemon to actually do anything;
  # TLP (which managed this before) is disabled in power.nix to avoid the two
  # fighting over the CPU governor.
  services.power-profiles-daemon.enable = true;
}
