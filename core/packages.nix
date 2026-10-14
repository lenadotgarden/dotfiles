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

  # NetBird (self-hosted mesh VPN); the `netbird`/`netbird-ui` packages in
  # home/default.nix are just the CLI/tray - this is the daemon that actually
  # owns /var/run/netbird/sock, without which `netbird up` can't connect.
  services.netbird.enable = true;

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

  # Power management (TLP) is configured per host
  # (hosts/macbook/asahi.nix, hosts/thinkpad/power.nix)

  # Gestion de la fermeture du clapet (Lid switch / Sleep mode)
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };

  # Enable Zsh shell system-wide
  programs.zsh.enable = true;

  # Allow Unfree, Unsupported Systems & Insecure Packages
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowUnsupportedSystem = true;
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
    inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.google-antigravity-cli
  ];

  # Syncthing Service
  services.syncthing = {
    enable = true;
    user = "lena";
    dataDir = "/home/lena";
    configDir = "/home/lena/.config/syncthing";
  };

  # XWayland pour exécuter les apps X11 sous Wayland
  programs.xwayland.enable = true;

  # Niri is installed per user (home/desktops/niri); the system only provides
  # what a compositor session needs.
  security.polkit.enable = true;
  hardware.graphics.enable = true;

  # Blip (P2P file transfer - https://blip.net), packaged by upstream's own flake
  programs.blip.enable = true;

  # XDG Desktop Portals (Requis pour Flameshot / Screen sharing)
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    # Niri sessions (XDG_CURRENT_DESKTOP=niri): screencast via the GNOME portal
    config.niri.default = [ "gnome" "gtk" ];
  };
}
