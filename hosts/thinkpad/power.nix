{ config, lib, pkgs, ... }:

# TLP is gone (see dms.nix): it fought power-profiles-daemon over the CPU
# governor, and DMS's power-saver button needs ppd to actually work. Battery
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
