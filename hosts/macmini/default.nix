{ config, lib, pkgs, ... }:

# Mac mini 2014 (Macmini7,1): i5-4278U (Haswell, 2c/4t), Intel Iris 5100, 16 GB, 256 GB SSD.
# Same desktop as the ThinkPad (niri + Dux Shell, xMonad fallback): users, dms and
# xmonad modules are shared with hosts/thinkpad/.
{
  imports = [
    ../../core/boot.nix
    ../../core/networking.nix
    ../../core/fonts.nix
    ../../core/packages.nix
    # Generated on the Mac mini: cp /etc/nixos/hardware-configuration.nix hosts/macmini/
    ./hardware-configuration.nix
    ../thinkpad/users.nix
    ../thinkpad/xmonad.nix
    ../thinkpad/dms.nix
    ./remote-access.nix
  ];

  networking.hostName = "macmini";

  console.keyMap = "fr";
  console.earlySetup = true;
  services.xserver.xkb.layout = "fr";
  services.xserver.xkb.variant = "mac"; # old Apple keyboard (with numpad)

  # Same kernel line as the ThinkPad (NixOS default LTS).
  boot.kernelPackages = pkgs.linuxPackages;

  # Apple EFI: writing boot entries to NVRAM is unreliable. systemd-boot is still
  # installed to the ESP; hold Option at power-on if the Mac doesn't pick it up.
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # Intel iGPU (Haswell, gen 7.5): Mesa for niri + VA-API for video decode.
  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.intel-vaapi-driver ];
  };
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  # Wi-Fi: the Broadcom BCM4360 needs the proprietary `wl` driver (broadcom-sta,
  # flagged insecure in nixpkgs). Ethernet works out of the box; if `wl` fails to
  # build on a new kernel, use Ethernet or a USB Wi-Fi dongle instead.
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "wl" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
  boot.blacklistedKernelModules = [ "b43" "bcma" "ssb" "brcmsmac" "brcmfmac" ];
  nixpkgs.config.allowInsecurePredicate = pkg: lib.getName pkg == "broadcom-sta";

  # Fan curve through applesmc.
  services.mbpfan.enable = true;

  # 16 GB of RAM: a smaller swapfile than the ThinkPad's is enough for the big
  # Rust flake builds (zram swap from core/ comes first).
  swapDevices = [ { device = "/var/lib/swapfile"; size = 8 * 1024; } ];

  # Mac mini has no battery or backlight; nothing from hosts/thinkpad/power.nix.

  system.stateVersion = "25.11";
}
