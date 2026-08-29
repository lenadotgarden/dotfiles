{ config, lib, pkgs, inputs, ... }:

{
  # Nix command & Flakes enable
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # LocalSend avec ouverture du pare-feu
  programs.localsend = {
    enable = true;
    openFirewall = true;
  };

  # KDE Connect avec ouverture du pare-feu
  programs.kdeconnect = {
    enable = true;
  };

  # Tailscale (Client pour Headscale)
  services.tailscale.enable = true;

  # Asahi / Apple Silicon support
  hardware.asahi.enable = true;
  hardware.asahi.extractPeripheralFirmware = true;
  hardware.asahi.peripheralFirmwareDirectory = ../firmware;

  # Bluetooth enable
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;

  # Time Zone & Locale
  time.timeZone = "Europe/Paris";

  # Dynamic RAM compression (zram swap)
  zramSwap.enable = true;

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

  # Gestion d'énergie (TLP & Powertop)
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_BAT = "performance";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      ENERGY_PERF_POLICY_ON_BAT = "performance";
      ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_MIN_PERF_ON_BAT = 100;
      CPU_MAX_PERF_ON_BAT = 100;
      RUNTIME_PM_ON_BAT = "on";
    };
  };

  powerManagement.powertop.enable = true;

  # Gestion de la fermeture du clapet (Lid switch / Sleep mode)
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };

  # Enable Zsh shell system-wide
  programs.zsh.enable = true;

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

  # XDG Desktop Portals pour Wayland (Requis pour Flameshot / Screen sharing)
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
  };
}
