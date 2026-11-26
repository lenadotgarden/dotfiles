{ config, lib, pkgs, compositor, ... }:

# System side of the Wayland desktop shared by thinkpad and macmini
# (Noctalia shell + sway or MangoWC). The compositor is picked once, in flake.nix
# (`compositor = "sway"` or `"mango"`); the per-user config lives in
# home/desktops/wayland. The session starts from the TTY1 autologin (home/zsh).
{
  config = lib.mkMerge [
    (lib.optionalAttrs (compositor == "sway") {
      programs.sway = {
        enable = true;
        wrapperFeatures.gtk = true;
      };
    })

    # programs.mango is declared by inputs.mango.nixosModules.mango, which
    # flake.nix only adds when mango is picked.
    (lib.optionalAttrs (compositor == "mango") {
      programs.mango.enable = true;
    })

    {
      # Needed by home-manager (dconf.settings) and GTK apps
      programs.dconf.enable = true;

      services.libinput = {
        enable = true;
        touchpad = {
          tapping = true;
          naturalScrolling = true;
          disableWhileTyping = true;
        };
      };

      # Iosevka is the system font (sans, serif, mono): GTK, Qt, Electron, Noctalia
      fonts.fontconfig.defaultFonts = {
        sansSerif = [ "Iosevka" ];
        serif = [ "Iosevka" ];
        monospace = [ "Iosevka" ];
      };

      # Backlight keys without root
      services.udev.packages = [ pkgs.brightnessctl ];
      users.users.lena.extraGroups = [ "video" ];

      # Noctalia's power-profile button needs it (NetworkManager, upower, bluetooth
      # and pipewire already come from core/).
      services.power-profiles-daemon.enable = true;
    }
  ];
}
