{ config, lib, pkgs, ... }:

{
  services.tlp = {
    enable = true;
    settings = {
      # Zen+ CPUs use acpi-cpufreq (no amd-pstate), where "powersave" pins the
      # lowest frequency. schedutil scales with load instead.
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";

      # Battery care: only charge between 75% and 80%.
      # Plug in and set STOP to 100 when you need a full charge (e.g. travelling).
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };
}
