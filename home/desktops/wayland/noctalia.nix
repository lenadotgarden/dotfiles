{ config, lib, pkgs, compositor, wlHost, ... }:

# Noctalia v5 config (~/.config/noctalia/config.toml). Noctalia's own settings UI
# writes to ~/.local/state/noctalia/settings.toml, which wins over this file, so
# tweaking in the UI never fights with the Nix config.
#
# Look: strictly monochrome (neutral greys, palettes/Mono.json, dark AND light),
# square corners everywhere, Iosevka, a flat full-width bar at the bottom with a
# single hairline on top. Panels are solid (no blur, no shadow: cheap on old iGPUs).
# Dark/light: Super+D (noctalia msg theme-mode-toggle). Every app that has a
# Noctalia template (ghostty, gtk, btop, the compositor borders) follows.
let
  templates = [ "ghostty" "gtk3" "gtk4" "btop" compositor ];

  reload = if compositor == "sway" then "swaymsg reload" else "mmsg dispatch reload_config";

  endWidgets = [ "media" "tray" "sysmon" "volume" ]
    ++ lib.optionals wlHost.laptop [ "brightness" "battery" ]
    ++ [ "notifications" "control-center" ];

  settings = {
    shell = {
      font_family = "Iosevka";
      corner_radius_scale = 0.0;          # square
      panel = {
        transparency_mode = "solid";
        borders = true;
        border_color = "outline_variant";
      };
      animation.speed = 1.4;              # snappy
      shadow.alpha = 0.0;                 # flat
    };

    theme = {
      mode = "dark";
      source = "custom";
      custom_palette = "Mono";
      templates = {
        enable_builtin_templates = true;
        builtin_ids = templates;
        enable_community_templates = false;
      };
    };

    # No wallpaper by default: a flat surface colour (drop monochrome images in
    # ~/Pictures/Wallpapers and they are used instead).
    wallpaper = {
      enabled = true;
      fill_mode = "crop";
      fill_color = "surface";
      directory = "${config.home.homeDirectory}/Pictures/Wallpapers";
      transition = [ "fade" ];
      transition_duration = 600;
      automation.enabled = false;
    };

    bar = {
      order = [ "main" ];
      main = {
        position = "bottom";
        thickness = 30;
        background_opacity = 1.0;
        compositor_blur = false;
        shadow = false;
        radius = 0;
        radius_top_left = 0;
        radius_top_right = 0;
        radius_bottom_left = 0;
        radius_bottom_right = 0;
        concave_edge_corners = false;
        margin_edge = 0;
        margin_ends = 0;
        padding = 12;
        widget_spacing = 16;
        font_weight = 500;
        border = "outline_variant";
        border_width = 1.0;
        capsule = false;
        reserve_space = true;
        start = [ "workspaces" "active_window" ];
        center = [ "clock" ];
        end = endWidgets;
      };
    };

    widget = {
      clock.format = "{:%a %d %b   %H:%M}";
      workspaces = {
        style = "minimal";
        labels_only_when_occupied = true;
        separator = "·";
      };
    };

    dock.enabled = false;
    backdrop.enabled = false;
    notification.background_opacity = 1.0;

    # Noctalia does idle, lock and screen-off itself (no hypridle/hyprlock)
    lockscreen = {
      blur_intensity = 0.0;
      tint_intensity = 1.0;
      tint_color = "surface";
    };
    idle = {
      behavior_order = [ "lock" "screen-off" "suspend" ];
      behavior = {
        lock = { timeout = 600; action = "lock"; enabled = true; };
        screen-off = { timeout = 660; action = "screen_off"; enabled = true; };
        suspend = { timeout = 1200; action = "lock_and_suspend"; enabled = true; };
      };
    };

    # sway / mango only pick up the generated colours on reload
    hooks.colors_changed = reload;
  };
in
{
  xdg.configFile."noctalia/config.toml".source =
    (pkgs.formats.toml { }).generate "noctalia-config.toml" settings;
  xdg.configFile."noctalia/palettes/Mono.json".source = ./palettes/Mono.json;
}
