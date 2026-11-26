{ config, lib, pkgs, compositor, wlHost, ... }:

# Noctalia v5 config (~/.config/noctalia/config.toml). Noctalia's own settings UI
# writes to ~/.local/state/noctalia/settings.toml, which wins over this file, so
# tweaking in the UI never fights with the Nix config.
#
# Look: floating island bar (capsules, no background) like the old DMS/Noctalia
# setup, an auto-hiding dock at the bottom, solid panels (no blur: cheaper on
# the Vega 8 / Iris 5100). Colours: ONE palette for everything.
let
  # "builtin" = fixed palette below (Catppuccin, same as the old kitty colours),
  # "wallpaper" = colours extracted from the current wallpaper (like pywal/matugen did).
  themeSource = "builtin";
  themeBuiltin = "Catppuccin";

  # Built-in Noctalia templates: Noctalia rewrites these files on every palette
  # change, so apps follow the theme live. ghostty also themes zsh (ANSI colours).
  templates = [ "ghostty" "gtk3" "gtk4" "btop" compositor ];

  reload = if compositor == "sway" then "swaymsg reload" else "mmsg dispatch reload_config";

  endWidgets = [ "tray" "notifications" "volume" ]
    ++ lib.optionals wlHost.laptop [ "brightness" "battery" ]
    ++ [ "control-center" ];

  settings = {
    shell = {
      font_family = "Iosevka";
      corner_radius_scale = 1.4;
      panel.transparency_mode = "solid";
      animation.speed = 1.2;
      shadow.alpha = 0.45;
    };

    theme = {
      mode = "dark";
      source = themeSource;
      builtin = themeBuiltin;
      wallpaper_scheme = "m3-tonal-spot";
      templates = {
        enable_builtin_templates = true;
        builtin_ids = templates;
        enable_community_templates = false;
      };
    };

    wallpaper = {
      enabled = true;
      fill_mode = "crop";
      directory = "${config.home.homeDirectory}/Pictures/Wallpapers";
      transition = [ "fade" "wipe" "disc" ];
      transition_duration = 900;
      automation = {
        enabled = true;
        interval_seconds = 3600;
        order = "random";
      };
    };

    # Island bar: transparent strip, floating capsules per widget
    bar = {
      order = [ "main" ];
      main = {
        position = "top";
        thickness = 40;
        background_opacity = 0.0;
        compositor_blur = false;
        shadow = false;
        radius = 18;
        margin_edge = 6;
        margin_ends = 10;
        padding = 6;
        widget_spacing = 8;
        font_scale = 1.05;
        capsule = true;
        capsule_fill = "surface_container";
        capsule_opacity = 0.96;
        capsule_border = "outline_variant";
        capsule_border_width = 1.0;
        reserve_space = true;
        start = [ "launcher" "clock" "sysmon" "active_window" "media" ];
        center = [ "workspaces" ];
        end = endWidgets;
        dead_zone.click_through = true;
      };
    };

    widget = {
      clock.format = "{:%a %d %b  %H:%M}";
      workspaces = {
        style = "regular";
        labels_only_when_occupied = true;
      };
    };

    # Floating dock, hidden until the pointer reaches the bottom edge
    dock = {
      enabled = true;
      position = "bottom";
      icon_size = 44;
      radius = 18;
      margin_edge = 8;
      background_opacity = 0.92;
      compositor_blur = false;
      magnification = false;
      auto_hide = true;
      reserve_space = false;
      show_running = true;
      pinned = [ "com.mitchellh.ghostty" "librewolf" ];
    };

    backdrop.enabled = false;

    notification.background_opacity = 0.95;

    # Noctalia does idle, lock and screen-off itself (no hypridle/hyprlock)
    lockscreen = {
      blur_intensity = 0.5;
      tint_intensity = 0.35;
    };
    idle = {
      behavior_order = [ "lock" "screen-off" "suspend" ];
      behavior = {
        lock = { timeout = 600; action = "lock"; enabled = true; };
        screen-off = { timeout = 660; action = "screen_off"; enabled = true; };
        suspend = { timeout = 1200; action = "lock_and_suspend"; enabled = true; };
      };
    };

    # sway only picks up the generated colours on reload; mango too
    hooks.colors_changed = reload;
  };
in
{
  xdg.configFile."noctalia/config.toml".source =
    (pkgs.formats.toml { }).generate "noctalia-config.toml" settings;
}
