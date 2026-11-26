{ config, lib, pkgs, inputs, compositor, wlHost, ... }:

# Noctalia shell + sway or MangoWC (picked in flake.nix with `compositor`).
# Same shortcuts on both: Super = apps and session, Alt = window navigation
# (Option / Cmd on the Apple keyboard, the ThinkPad swaps Alt and Win in xkb).
# Colours: Noctalia generates them (sway/noctalia, mango/noctalia.conf, ghostty
# theme, gtk, btop) and both compositors include its files, see noctalia.nix.
let
  system = pkgs.stdenv.hostPlatform.system;
  noctaliaPkg = inputs.self.packages.${system}.myNoctalia;
  noctalia = lib.getExe noctaliaPkg;
  ipc = "${noctalia} msg";
  term = lib.getExe pkgs.ghostty;
  rofimojiBin = lib.getExe pkgs.rofimoji;

  # AZERTY: the digit row gives symbols without Shift
  azertyDigits = [ "ampersand" "eacute" "quotedbl" "apostrophe" "parenleft" ];
  wsKeys = lib.imap1 (i: k: { n = toString i; key = k; }) azertyDigits;

  nvimGarden = "${term} --working-directory=${config.home.homeDirectory}/Garden -e nvim";

  # Placeholder colours (Mono, dark) used until Noctalia renders its own
  # files on first start; Noctalia then overwrites them on every palette change.
  seedSway = ''
    set $primary            #ededed
    set $on_primary         #111111
    set $secondary          #bdbdbd
    set $tertiary           #8a8a8a
    set $error              #c9a3a3
    set $surface            #111111
    set $on_surface         #e4e4e4
    set $on_surface_variant #8f8f8f
    set $outline            #333333

    client.focused          $primary  $surface  $on_surface         $primary   $primary
    client.focused_inactive $outline  $surface  $on_surface_variant $outline   $outline
    client.unfocused        $outline  $surface  $on_surface_variant $outline   $outline
    client.urgent           $error    $surface  $on_surface         $error     $error
    client.placeholder      $surface  $surface  $on_surface_variant $surface   $surface
    client.background       $surface
  '';
  seedGhostty = ''
    palette = 0=#2e2e2e
    palette = 1=#c9a3a3
    palette = 2=#a3a3a3
    palette = 3=#bdbdbd
    palette = 4=#8f8f8f
    palette = 5=#cfcfcf
    palette = 6=#9a9a9a
    palette = 7=#d4d4d4
    palette = 8=#666666
    palette = 9=#dbb8b8
    palette = 10=#b8b8b8
    palette = 11=#d8d8d8
    palette = 12=#a8a8a8
    palette = 13=#e6e6e6
    palette = 14=#b0b0b0
    palette = 15=#ffffff
    background = #111111
    foreground = #e4e4e4
    cursor-color = #ededed
    selection-background = #3a3a3a
    selection-foreground = #ffffff
  '';
in
{
  imports = [ ./noctalia.nix ]
    ++ lib.optional (compositor == "mango") inputs.mango.hmModules.mango;

  config = lib.mkMerge [
    {
      home.packages = with pkgs; [
        noctaliaPkg
        wl-clipboard
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
        TERMINAL = "ghostty";
      };

      # Files that Noctalia owns and rewrites (so they can't be read-only store
      # symlinks): seed them once so the first login already has colours.
      home.activation.seedNoctaliaFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        seed() {
          if [ ! -e "$1" ]; then
            run mkdir -p "$(dirname "$1")"
            printf '%s' "$2" > "$1"
          fi
        }
        seed "$HOME/.config/ghostty/themes/noctalia" ${lib.escapeShellArg seedGhostty}
        ${lib.optionalString (compositor == "sway") ''seed "$HOME/.config/sway/noctalia" ${lib.escapeShellArg seedSway}''}
      '';
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
          gaps = { inner = 6; outer = 0; };
          window = { border = 3; titlebar = false; };
          floating = { border = 3; titlebar = false; };
          focus.followMouse = "no";

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
            { command = "sleep 2 && ${ipc} session lock"; } # lock at login (TTY autologin)
          ];

          modes.resize = {
            h = "resize shrink width 20 px";
            l = "resize grow width 20 px";
            k = "resize shrink height 20 px";
            j = "resize grow height 20 px";
            Escape = "mode default";
            Return = "mode default";
          };

          keybindings = {
            "Mod4+Return" = "exec ${term}";
            "Mod4+o" = "exec ${nvimGarden}";
            "Mod4+space" = "exec ${ipc} panel-toggle launcher";
            "Mod4+s" = "exec ${ipc} panel-toggle control-center";
            "Mod4+comma" = "exec ${ipc} settings-toggle";
            "Mod4+Shift+l" = "exec ${ipc} session lock";
            "Mod4+d" = "exec ${ipc} theme-mode-toggle";
            "Ctrl+Mod4+space" = "exec ${rofimojiBin} --action type";
            "Ctrl+Shift+s" = "exec ${ipc} screenshot-region";
            "Mod1+Tab" = "exec ${ipc} window-switcher hold";
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
            "Mod1+r" = "mode resize";

            "--locked XF86AudioRaiseVolume" = "exec ${ipc} volume-up 5";
            "--locked XF86AudioLowerVolume" = "exec ${ipc} volume-down 5";
            "--locked XF86AudioMute" = "exec ${ipc} volume-mute";
            "--locked XF86AudioPlay" = "exec ${ipc} media toggle";
            "--locked XF86AudioNext" = "exec ${ipc} media next";
            "--locked XF86AudioPrev" = "exec ${ipc} media previous";
            "--locked XF86MonBrightnessUp" = "exec ${ipc} brightness-up 5";
            "--locked XF86MonBrightnessDown" = "exec ${ipc} brightness-down 5";
          }
          // lib.listToAttrs (lib.concatMap (w: [
            { name = "Mod1+${w.n}"; value = "workspace number ${w.n}"; }
            { name = "Mod1+Shift+${w.n}"; value = "move container to workspace number ${w.n}"; }
            { name = "Mod1+${w.key}"; value = "workspace number ${w.n}"; }
            { name = "Mod1+Shift+${w.key}"; value = "move container to workspace number ${w.n}"; }
          ]) wsKeys);
        };
        # Last line wins: Noctalia's generated client.* colours override the defaults above.
        # (written as `include ~/...` so Noctalia's own apply script finds it and leaves the file alone)
        # Trackpad: 3 fingers = move focus, 4 fingers = workspaces (natural direction)
        extraConfig = ''
          bindgesture swipe:3:left focus right
          bindgesture swipe:3:right focus left
          bindgesture swipe:3:up focus down
          bindgesture swipe:3:down focus up
          bindgesture swipe:4:left workspace next
          bindgesture swipe:4:right workspace prev

          include ~/.config/sway/noctalia
        '';
      };
    }

    # --------------------------------------------------------------- mango
    # wayland.windowManager.mango only exists when its home-manager module is imported
    (lib.optionalAttrs (compositor == "mango") {
      wayland.windowManager.mango = {
        enable = true;
        autostart_sh = ''
          ${noctalia} &
          (sleep 2 && ${ipc} session lock) &
        '';
        # Noctalia writes ~/.config/mango/noctalia.conf (colours); optional until its first run
        extraConfig = ''
          source_optional=~/.config/mango/noctalia.conf
          # after it, so these border colours win (see noctalia.nix, template mango-borders)
          source_optional=~/.config/mango/noctalia-borders.conf
        '';
        settings = {
          xkb_rules_layout = "fr";
          repeat_delay = 250;
          repeat_rate = 25;
          tap_to_click = 1;
          trackpad_natural_scrolling = 1;
          trackpad_disable_while_typing = 1;

          # Light on the iGPU: no blur, no shadows, no transparency.
          # Noctalia animates its own surfaces: layer animations off (its docs).
          blur = 0;
          shadows = 0;
          layer_shadows = 0;
          layer_animations = 0;
          focused_opacity = 1.0;
          unfocused_opacity = 1.0; # no transparency anywhere (battery)
          border_radius = 0;
          border_px = 3;
          no_border_when_single = 1; # border only when the workspace has 2+ windows
          gap_inner_horizontal = 6;
          gap_inner_vertical = 6;
          gap_outer_horizontal = 7;
          gap_outer_vertical = 7;
          smart_gaps = 0;

          # Animations: short, ease-out (quint), no bounce. Windows zoom in and fade out,
          # tags and moves glide. Layer animations stay off (Noctalia draws its own).
          animations = 1;
          animation_type_open = "zoom";
          animation_type_close = "fade";
          animation_fade_in = 1;
          animation_fade_out = 1;
          zoom_initial_ratio = 0.9;
          fade_in_begin_opacity = 0.6;
          animation_duration_open = 140;
          animation_duration_close = 100;
          animation_duration_move = 150;
          animation_duration_tag = 150;
          animation_duration_focus = 0;
          animation_curve_open = "0.22,1.0,0.36,1.0";
          animation_curve_move = "0.22,1.0,0.36,1.0";
          animation_curve_tag = "0.22,1.0,0.36,1.0";
          animation_curve_focus = "0.22,1.0,0.36,1.0";
          animation_curve_close = "0.5,0.0,0.75,0.0";

          sloppy_focus = 0;
          tag_num = 5;

          # niri-like columns
          tag_rule = map (n: "id:${toString n},layout_name:scroller") (lib.range 1 5);
          # scroller tuning: presets like niri (1/3, 1/2, 2/3, full), Alt+R cycles them,
          # also with a single window (ignored by default)
          scroller_ignore_proportion_single = 0;
          scroller_default_proportion = 0.5;
          scroller_default_proportion_single = 1.0;
          scroller_proportion_preset = "0.333,0.5,0.667,1.0";
          scroller_structs = 0;           # no reserved strip on the sides
          scroller_prefer_center = 0;     # centring pushed windows away from the screen edges

          # Trackpad: 3 fingers = move focus between columns, 4 fingers = tags / overview
          gesture_live = 1;
          gesturebind = [
            "none,left,3,focusdir,right"
            "none,right,3,focusdir,left"
            "none,up,3,focusdir,down"
            "none,down,3,focusdir,up"
            "none,left,4,viewnext_have_client"
            "none,right,4,viewprev_have_client"
            "none,up,4,toggleoverview"
            "none,down,4,toggleoverview"
          ];

          bind = [
            "SUPER,Return,spawn,${term}"
            "SUPER,o,spawn_shell,${nvimGarden}"
            "SUPER,space,spawn_shell,${ipc} panel-toggle launcher"
            "SUPER,s,spawn_shell,${ipc} panel-toggle control-center"
            "SUPER,comma,spawn_shell,${ipc} settings-toggle"
            "SUPER+SHIFT,l,spawn_shell,${ipc} session lock"
            "SUPER,d,spawn_shell,${ipc} theme-mode-toggle"
            "CTRL+SUPER,space,spawn_shell,${rofimojiBin} --action type"
            "CTRL+SHIFT,s,spawn_shell,${ipc} screenshot-region"
            "ALT,Tab,spawn_shell,${ipc} window-switcher hold"
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

            "NONE,XF86AudioRaiseVolume,spawn_shell,${ipc} volume-up 5"
            "NONE,XF86AudioLowerVolume,spawn_shell,${ipc} volume-down 5"
            "NONE,XF86AudioMute,spawn_shell,${ipc} volume-mute"
            "NONE,XF86AudioPlay,spawn_shell,${ipc} media toggle"
            "NONE,XF86AudioNext,spawn_shell,${ipc} media next"
            "NONE,XF86AudioPrev,spawn_shell,${ipc} media previous"
            "NONE,XF86MonBrightnessUp,spawn_shell,${ipc} brightness-up 5"
            "NONE,XF86MonBrightnessDown,spawn_shell,${ipc} brightness-down 5"
          ]
          # AZERTY symbol names only: with the fr layout "1" and "ampersand" are the same key,
          # and mango rejects the duplicate as a binding conflict.
          ++ lib.concatMap (w: [
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
