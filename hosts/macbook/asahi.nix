{ config, lib, pkgs, ... }:

# Everything specific to the Apple Silicon MacBook (Asahi Linux).
# Shared settings live in core/, never put these there.
{
  # Asahi / Apple Silicon support
  hardware.asahi.enable = true;
  hardware.asahi.extractPeripheralFirmware = true;
  hardware.asahi.peripheralFirmwareDirectory = ../../firmware;

  # Display notch
  boot.kernelParams = [
    "appledrm.show_notch=1"
    "apple_dcp.show_notch=1"
  ];

  environment.systemPackages = with pkgs; [
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
}
