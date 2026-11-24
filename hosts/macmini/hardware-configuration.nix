# PLACEHOLDER - replace on the Mac mini after installing NixOS:
#   cp /etc/nixos/hardware-configuration.nix hosts/macmini/hardware-configuration.nix
# The module list matches a Macmini7,1 (PCIe SSD, Haswell); the filesystems are
# generic labels, the real UUIDs come from nixos-generate-config.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];

  fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/BOOT";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
