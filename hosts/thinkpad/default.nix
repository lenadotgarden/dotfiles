{ config, lib, pkgs, ... }:

# Lenovo ThinkPad T495s (Ryzen 3000 mobile, Vega graphics, NVMe, LUKS).
{
  imports = [
    ../../core/boot.nix
    ../../core/networking.nix
    ../../core/fonts.nix
    ../../core/packages.nix
    # Generated on the laptop: cp /etc/nixos/hardware-configuration.nix hosts/thinkpad/
    ./hardware-configuration.nix
    ./users.nix
    ./power.nix
  ];

  networking.hostName = "thinkpad";

  # AZERTY in the TTY and at the LUKS passphrase prompt
  console.keyMap = "fr";
  console.earlySetup = true;
  # AZERTY for X11 sessions (xMonad). Niri takes its layout from the flake.
  services.xserver.xkb.layout = "fr";

  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.enableRedistributableFirmware = true; # amdgpu + Wi-Fi firmware
  hardware.graphics.enable = true;
  services.fwupd.enable = true;                  # BIOS/firmware updates from Linux

  # Set this to the value in your installer-generated /etc/nixos/configuration.nix
  system.stateVersion = "25.11";
}
