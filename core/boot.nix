{ config, lib, pkgs, inputs, ... }:

{
  # Bootloader & Kernel
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [
    "appledrm.show_notch=1"
    "apple_dcp.show_notch=1"
  ];
}
