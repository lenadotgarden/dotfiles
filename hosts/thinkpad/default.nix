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
    ../../core/wayland.nix # Noctalia + sway or mango (flake.nix `compositor`)
  ];

  networking.hostName = "thinkpad";

  # AZERTY in the TTY and at the LUKS passphrase prompt (the compositor sets its own, see flake.nix)
  console.keyMap = "fr";
  console.earlySetup = true;

  # Not _latest: 7.3 hangs niri's backend init on this Raven/Picasso iGPU after
  # config-load, with zero kernel-log errors (silent userspace deadlock, confirmed
  # across repeated boots on 2026-10-22 during the Dux Shell migration). The known-good
  # pre-migration line (7.1) is already EOL/removed from nixpkgs, so fall back to
  # NixOS's own curated default instead of hand-pinning another _latest version.
  boot.kernelPackages = pkgs.linuxPackages;

  # Disk swap on top of the zram swap from core/: big builds (Rust flake inputs
  # like niri, yazi, handy) otherwise get nix OOM-killed. The file lives on the
  # LUKS volume, so it is encrypted.
  swapDevices = [ { device = "/var/lib/swapfile"; size = 16 * 1024; } ];

  hardware.enableRedistributableFirmware = true; # amdgpu + Wi-Fi firmware
  services.fwupd.enable = true;                  # BIOS/firmware updates from Linux

  # Set this to the value in your installer-generated /etc/nixos/configuration.nix
  system.stateVersion = "25.11";
}
