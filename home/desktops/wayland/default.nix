{ config, lib, pkgs, inputs, compositor, wlHost, ... }:

# Noctalia shell + sway or MangoWC (picked in flake.nix with `compositor`).
# Same shortcuts on both: Super = apps and session, Alt = window navigation
# (Option / Cmd on the Apple keyboard, the ThinkPad swaps Alt and Win in xkb).
let
  system = pkgs.stdenv.hostPlatform.system;
  noctalia = lib.getExe inputs.self.packages.${system}.myNoctalia;
  term = lib.getExe pkgs.kitty;
  hyprlock = lib.getExe pkgs.hyprlock;
  rofimojiBin = lib.getExe pkgs.rofimoji;

  # AZERTY: the digit row gives symbols without Shift
  azertyDigits = [ "ampersand" "eacute" "quotedbl" "apostrophe" "parenleft" ];

  wsKeys = lib.imap1 (i: k: { n = toString i; key = k; }) azertyDigits;

  screenshot = ''grim -g "$(slurp)" - | swappy -f -'';
  launcher = "${noctalia} msg panel-toggle launcher";

  # Dark palette shared with kitty (#11111b)
  colors = { focus = "b4befe"; idle = "313244"; root = "11111b"; };
in
{
  imports = lib.optional (compositor == "mango") inputs.mango.hmModules.mango;

  config = lib.mkMerge [
  {
  home.packages = with pkgs; [
    inputs.self.packages.${system}.myNoctalia
    grim
    slurp
    swappy
    wl-clipboard
    wlopm
    rofimoji
    wtype
    brightnessctl
    kdePackages.dolphin
  ];

  services.network-manager-applet.enable = true;
  services.kdeconnect = {
    enable = true;
    indicator = true;
  };

  home.sessionVariables = {
    DEFAULT_WM = compositor; # read by home/zsh to start the session on TTY1
    NIXOS_OZONE_WL = "1";    # Electron apps natively on Wayland
  };

  }

  # --------------------------------------------------------------- sway
  {
  wayland.windowManager.sway = lib.mkIf (compositor == "sway") {
    enable = true;
    package = null; # installed by programs.sway (core/wayland.nix)
    checkConfig = false; # needs the package; sway validates on reload
    config = {
      modifier = "Mod4";
      terminal = term;
      bars = [ ]; # Noctalia is the bar
      gaps = { inner = 10; outer = 4; };
      window = { border = 2; titlebar = false; };
      floating = { border = 2; titlebar = false; };
      focus.followMouse = "no";

      colors = {
        focused = { border = "#${colors.focus}"; background = "#${colors.focus}"; text = "#${colors.root}"; indicator = "#${colors.focus}"; childBorder = "#${colors.focus}"; };
        focusedInactive = { border = "#${colors.idle}"; background = "#${colors.idle}"; text = "#ffffff"; indicator = "#${colors.idle}"; childBorder = "#${colors.idle}"; };
        unfocused = { border = "#${colors.idle}"; background = "#${colors.root}"; text = "#ffffff"; indicator = "#${colors.idle}"; childBorder = "#${colors.idle}"; };
      };

      input = {
        "type:keyboard" = {
          xkb_layout = "fr";
          repeat_delay = "250";
          repeat_rate = "25";
        }
        // lib.optionalAttrs (wlHost.xkbVariant != null) { xkb_variant = wlHost.xkbVariant; }
        // lib.optionalAttrs (wlHost.xkbOptions != null) { xkb_options = wlHost.xkbOptions; };
        "type:touchpad" = {
          tap = "enabled";
          natural_scroll = "enabled";
          dwt = "enabled";
        };
      };

      startup = [
        { command = noctalia; }
        { command = "sleep 1 && ${hyprlock}"; }
      ];

      keybindings = {
        "Mod4+Return" = "exec ${term}";
        "Mod4+o" = "exec ${term} -d ~/Garden -e nvim";
        "Mod4+space" = "exec ${launcher}";
        "Ctrl+Mod4+space" = "exec ${rofimojiBin} --action type";
        "Ctrl+Shift+s" = "exec ${screenshot}";
        "Mod4+q" = "kill";
        "Mod4+Shift+r" = "reload";
        "Mod4+Shift+e" = "exit";

        "Mod1+h" = "focus left";
        "Mod1+l" = "focus right";
        "Mod1+k" = "focus up";
        "Mod1+j" = "focus down";
        "Mod1+Shift+h" = "move left";
        "Mod1+Shift+l" = "move right";
        "Mod1+Shift+k" = "move up";
        "Mod1+Shift+j" = "move down";

        "Mod1+f" = "fullscreen toggle";
        "Mod1+m" = "layout toggle split";
        "Mod1+t" = "layout tabbed";
        "Mod1+Shift+space" = "floating toggle";
        "Mod1+comma" = "splitv";
        "Mod1+period" = "splith";
        "Mod1+minus" = "resize shrink width 10 ppt";
        "Mod1+equal" = "resize grow width 10 ppt";
        "Mod1+Shift+minus" = "resize shrink height 10 ppt";
        "Mod1+Shift+equal" = "resize grow height 10 ppt";

        "--locked XF86AudioRaiseVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
        "--locked XF86AudioLowerVolume" = "exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
        "--locked XF86AudioMute" = "exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        "--locked XF86MonBrightnessUp" = "exec brightnessctl set 5%+";
        "--locked XF86MonBrightnessDown" = "exec brightnessctl set 5%-";
      }
      // lib.listToAttrs (lib.concatMap (w: [
        { name = "Mod1+${w.n}"; value = "workspace number ${w.n}"; }
        { name = "Mod1+Shift+${w.n}"; value = "move container to workspace number ${w.n}"; }
        { name = "Mod1+${w.key}"; value = "workspace number ${w.n}"; }
        { name = "Mod1+Shift+${w.key}"; value = "move container to workspace number ${w.n}"; }
      ]) wsKeys);
    };
  };

  }

  # wayland.windowManager.mango only exists when its home-manager module is imported
  (lib.optionalAttrs (compositor == "mango") {
  # --------------------------------------------------------------- mango
  wayland.windowManager.mango = {
    enable = true;
    autostart_sh = ''
      ${noctalia} &
      (sleep 1 && ${hyprlock}) &
    '';
    settings = {
      xkb_rules_layout = "fr";
      repeat_delay = 250;
      repeat_rate = 25;
      tap_to_click = 1;
      trackpad_natural_scrolling = 1;
      trackpad_disable_while_typing = 1;

      # Light on the iGPU: no blur, no shadows, no transparency
      blur = 0;
      shadows = 0;
      layer_shadows = 0;
      focused_opacity = 1.0;
      unfocused_opacity = 1.0;
      border_radius = 10;
      border_px = 2;
      gap_inner_horizontal = 10;
      gap_inner_vertical = 10;
      gap_outer_horizontal = 4;
      gap_outer_vertical = 4;
      root_color = "0x${colors.root}ff";
      border_color = "0x${colors.idle}ff";
      focus_color = "0x${colors.focus}ff";

      sloppy_focus = 0;
      tag_num = 5;

      # niri-like columns
      tag_rule = map (n: "id:${toString n},layout_name:scroller") (lib.range 1 5);

      bind = [
        "SUPER,Return,spawn,${term}"
        "SUPER,o,spawn_shell,${term} -d ~/Garden -e nvim"
        "SUPER,space,spawn_shell,${launcher}"
        "CTRL+SUPER,space,spawn_shell,${rofimojiBin} --action type"
        "CTRL+SHIFT,s,spawn_shell,${screenshot}"
        "SUPER,q,killclient,"
        "SUPER+SHIFT,r,reload_config"
        "SUPER+SHIFT,e,quit"

        "ALT,h,focusdir,left"
        "ALT,l,focusdir,right"
        "ALT,k,focusdir,up"
        "ALT,j,focusdir,down"
        "ALT+SHIFT,h,exchange_client,left"
        "ALT+SHIFT,l,exchange_client,right"
        "ALT+SHIFT,k,exchange_client,up"
        "ALT+SHIFT,j,exchange_client,down"

        "ALT,f,togglefullscreen,"
        "ALT,m,togglemaximizescreen,"
        "ALT,r,switch_proportion_preset,"
        "ALT+SHIFT,space,togglefloating,"
        "ALT,minus,resizewin,-50,+0"
        "ALT,equal,resizewin,+50,+0"
        "ALT+SHIFT,minus,resizewin,+0,-50"
        "ALT+SHIFT,equal,resizewin,+0,+50"

        "NONE,XF86AudioRaiseVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        "NONE,XF86AudioLowerVolume,spawn,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        "NONE,XF86AudioMute,spawn,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        "NONE,XF86MonBrightnessUp,spawn,brightnessctl set 5%+"
        "NONE,XF86MonBrightnessDown,spawn,brightnessctl set 5%-"
      ]
      ++ lib.concatMap (w: [
        "ALT,${w.n},view,${w.n},0"
        "ALT+SHIFT,${w.n},tag,${w.n},0"
        "ALT,${w.key},view,${w.n},0"
        "ALT+SHIFT,${w.key},tag,${w.n},0"
      ]) wsKeys;

      mousebind = [
        "SUPER,btn_left,moveresize,curmove"
        "SUPER,btn_right,moveresize,curresize"
      ];
    }
    // lib.optionalAttrs (wlHost.xkbVariant != null) { xkb_rules_variant = wlHost.xkbVariant; }
    // lib.optionalAttrs (wlHost.xkbOptions != null) { xkb_rules_options = wlHost.xkbOptions; };
  };
  })
  ];
}
