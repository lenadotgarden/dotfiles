{ config, lib, pkgs, inputs, ... }:

{
  # Bootloader (UEFI). Kernel and kernel params are set per host.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
