{ config, lib, pkgs, inputs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  # Nix Flakes & nix-command support
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Asahi / Apple Silicon support
  hardware.asahi.enable = true;
  hardware.asahi.extractPeripheralFirmware = true;
  hardware.asahi.peripheralFirmwareDirectory = ../firmware;

  # Bluetooth enable
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "nixos-macbook";
  networking.networkmanager.enable = true;

  # Time Zone & Locale
  time.timeZone = "Europe/Paris";

  # Audio (Pipewire)
  security.rtkit.enable = true;
  services.upower.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # User Account
  users.users.lena = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "3141";
  };

  # Allow Unfree & Insecure Packages if necessary
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "electron-40.10.5"
  ];

  # System Packages (core tools)
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    brightnessctl
    kbdlight
    evtest
    actkbd
  ];

  # Hardware brightness keys (Asahi / MacBook)
  services.actkbd = {
    enable = true;
    bindings =
      let
        bctl = "${pkgs.brightnessctl}/bin/brightnessctl";
      in [
        {
          keys = [ 224 ]; # Brightness down
          events = [ "key" ];
          command = "${bctl} set 5%-";
        }
        {
          keys = [ 225 ]; # Brightness up
          events = [ "key" ];
          command = "${bctl} set 5%+";
        }
      ];
  };

  # Syncthing Service
  services.syncthing = {
    enable = true;
    user = "lena";
    dataDir = "/home/lena";
    configDir = "/home/lena/.config/syncthing";
  };

  # Fonts (Iosevka Nerd Font)
  fonts.packages = with pkgs; [
    iosevka-bin
  ];

  # Hyprland Compositor
  programs.hyprland.enable = true;

  # State version
  system.stateVersion = "25.11";
}
