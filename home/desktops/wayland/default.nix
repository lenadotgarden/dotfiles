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

  # Placeholder colours (Catppuccin Mocha) used until Noctalia renders its own
  # files on first start; Noctalia then overwrites them on every palette change.
  seedSway = ''
    set $primary            #b4befe
    set $on_primary         #11111b
    set $secondary          #cba6f7
    set $tertiary           #f5c2e7
    set $error              #f38ba8
    set $surface            #1e1e2e
    set $on_surface         #cdd6f4
    set $on_surface_variant #a6adc8
    set $outline            #45475a

    client.focused          $primary  $surface  $on_surface         $primary   $primary
    client.focused_inactive $outline  $surface  $on_surface_variant $outline   $outline
    client.unfocused        $outline  $surface  $on_surface_variant $outline   $outline
    client.urgent           $error    $surface  $on_surface         $error     $error
    client.placeholder      $surface  $surface  $on_surface_variant $surface   $surface
    client.background       $surface
  '';
  seedGhostty = ''
    palette = 0=#45475a
    palette = 1=#f38ba8
    palette = 2=#a6e3a1
    palette = 3=#f9e2af
    palette = 4=#89b4fa
    palette = 5=#f5c2e7
    palette = 6=#94e2d5
    palette = 7=#bac2de
    palette = 8=#585b70
    palette = 9=#f38ba8
    palette = 10=#a6e3a1
    palette = 11=#f9e2af
    palette = 12=#89b4fa
    palette = 13=#f5c2e7
    palette = 14=#94e2d5
    palette = 15=#a6adc8
    background = #1e1e2e
    foreground = #cdd6f4
    cursor-color = #f5e0dc
    selection-background = #585b70
    selection-foreground = #cdd6f4
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
          gaps = { inner = 10; outer = 4; };
          window = { border = 2; titlebar = false; };
          floating = { border = 2; titlebar = false; };
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

          keybindings = {
            "Mod4+Return" = "exec ${term}";
            "Mod4+o" = "exec ${nvimGarden}";
            "Mod4+space" = "exec ${ipc} panel-toggle launcher";
            "Mod4+s" = "exec ${ipc} panel-toggle control-center";
            "Mod4+comma" = "exec ${ipc} settings-toggle";
            "Mod4+Shift+l" = "exec ${ipc} session lock";
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
        extraConfig = ''
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
          unfocused_opacity = 1.0;
          border_radius = 10;
          border_px = 2;
          gap_inner_horizontal = 10;
          gap_inner_vertical = 10;
          gap_outer_horizontal = 4;
          gap_outer_vertical = 4;

          sloppy_focus = 0;
          tag_num = 5;

          # niri-like columns
          tag_rule = map (n: "id:${toString n},layout_name:scroller") (lib.range 1 5);

          bind = [
            "SUPER,Return,spawn,${term}"
            "SUPER,o,spawn_shell,${nvimGarden}"
            "SUPER,space,spawn_shell,${ipc} panel-toggle launcher"
            "SUPER,s,spawn_shell,${ipc} panel-toggle control-center"
            "SUPER,comma,spawn_shell,${ipc} settings-toggle"
            "SUPER+SHIFT,l,spawn_shell,${ipc} session lock"
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
