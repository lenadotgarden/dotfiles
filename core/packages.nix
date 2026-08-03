{ config, lib, pkgs, inputs, ... }:

{
  # Nix command & Flakes enable
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # LocalSend avec ouverture du pare-feu
  programs.localsend = {
    enable = true;
    openFirewall = true;
  };

  # Asahi / Apple Silicon support
  hardware.asahi.enable = true;
  hardware.asahi.extractPeripheralFirmware = true;
  hardware.asahi.peripheralFirmwareDirectory = ../firmware;

  # Bluetooth enable
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;

  # Time Zone & Locale
  time.timeZone = "Europe/Paris";

  # Audio (Pipewire) & Power Management for Audio
  security.rtkit.enable = true;
  services.upower.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.extraConfig = {
      "10-disable-idle-timeout" = {
        "wireplumber.settings" = {
          "session.suspend-timeout-seconds" = 5; # Mettre en veille le DAC audio après 5s de silence
        };
      };
    };
  };

  # Gestion d'énergie bas niveau (TLP & Powertop)
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      RUNTIME_PM_ON_BAT = "auto";
    };
  };

  powerManagement.powertop.enable = true;

  # Gestion de la fermeture du clapet (Lid switch / Sleep mode)
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };

  # Enable Fish shell system-wide
  programs.fish = {
    enable = true;
    useBabelfish = true;
  };

  # Allow Unfree & Insecure Packages
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
    inputs.antigravity-nix.packages.${pkgs.system}.default
    inputs.antigravity-nix.packages.${pkgs.system}.google-antigravity-cli
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

  # Hyprland Compositor system-level enablement
  programs.hyprland.enable = true;
}
