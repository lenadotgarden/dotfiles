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
      animation.enabled = false;          # panels (launcher...) open instantly
      shadow.alpha = 0.0;                 # flat

      # Launcher: lightest layout, no per-app origin lookups, no network refresh
      launcher = {
      layout = "simple";
      show_app_origin_indicator = false;
      fetch_exchange_rates = false;
      default_view = "recent";
      };
    };

    theme = {
      mode = "dark";
      source = "custom";
      custom_palette = "Mono";
      templates = {
        enable_builtin_templates = true;
        builtin_ids = templates;
        enable_community_templates = false;
      } // lib.optionalAttrs (compositor == "mango") {
        # Window borders: focused = palette primary (near white / near black), unfocused = a
        # surface step barely above the background. Much stronger contrast than the stock
        # mango template, which uses one mid-grey outline for all other windows.
        user.mango-borders = {
          input_path = "templates/mango-borders.conf";
          output_path = "$XDG_CONFIG_HOME/mango/noctalia-borders.conf";
        };
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
        capsule_radius = 0.0;       # also shapes the hover highlight: square, not a pill
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
        capsule_radius = 0.0;
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
  xdg.configFile."noctalia/templates/mango-borders.conf".text = ''
    border_color = 0x{{colors.surface_container_high.default.hex_stripped}}ff
    focus_color = 0x{{colors.primary.default.hex_stripped}}ff
    urgent_color = 0x{{colors.error.default.hex_stripped}}ff
  '';
}
