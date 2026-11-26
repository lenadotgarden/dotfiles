{ config, lib, pkgs, ... }:

# TLP is gone: it fought power-profiles-daemon (core/wayland.nix) over the CPU
# governor, and Noctalia's power-profile button needs ppd. Battery
# charge-threshold care (the one TLP feature worth keeping) is replicated
# directly via thinkpad_acpi's sysfs knobs below.
{
  systemd.services.battery-charge-thresholds = {
    description = "Set ThinkPad battery charge thresholds (care mode: 75-80%)";
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    # Plug in and bump stop to 100 manually when you need a full charge (e.g. travelling).
    script = ''
      echo 75 > /sys/class/power_supply/BAT0/charge_control_start_threshold
      echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold
    '';
  };
}
