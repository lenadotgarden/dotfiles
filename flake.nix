{
  description = "NixOS & Home Manager Configuration Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    flake-parts.url = "github:hercules-ci/flake-parts";
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";
    niri.url = "github:YaLTeR/niri";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-silicon-support.url = "github:tpwrules/nixos-apple-silicon";
    helium.url = "github:schembriaiden/helium-browser-nix-flake";
    antigravity-nix.url = "github:jacopone/antigravity-nix";
    fsel.url = "github:Mjoyufull/fsel";
    handy.url = "github:cjpais/Handy";
    yazi.url = "github:sxyazi/yazi";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-linux" "x86_64-linux" ];

      perSystem = { config, self', inputs', pkgs, system, lib, ... }: {
        # Custom wrapped packages (like Niri from the tutorial) go here
        packages.myNoctalia = inputs.wrapper-modules.wrappers.noctalia-shell.wrap {
          inherit pkgs;
          settings = builtins.fromJSON (builtins.readFile ./home/desktops/niri/noctalia.json);
        };

        packages.myNiri = inputs.wrapper-modules.wrappers.niri.wrap {
          package = inputs'.niri.packages.niri;
          inherit pkgs;
          settings = {
            prefer-no-csd = {};

            input.keyboard.xkb.layout = "fr"; 
            input.keyboard.xkb.variant = "mac";

            input.touchpad.click-method = "clickfinger";
            input.touchpad.natural-scroll = {};
            input.touchpad.scroll-factor = 0.25;

            outputs."eDP-1".scale = 1.5625;

            layout.gaps = 12;

            layout.border.off = {};
            layout.focus-ring.off = {};

            layout.shadow = {
              on = {};
              softness = 20.0;
              spread = 2.0;
              color = "#00000070";
            };

            window-rules = [
              {
                geometry-corner-radius = let r = 18.0; in [ r r r r ];
                clip-to-geometry = true;
              }
              {
                matches = [ { is-focused = false; } ];
                opacity = 0.65;
              }
              {
                matches = [ { is-focused = true; } ];
                opacity = 0.95;
              }
            ];

            xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

            spawn-at-startup = [
              (lib.getExe self'.packages.myNoctalia)
            ];
            binds = {
              "Mod+Return".spawn-sh = lib.getExe pkgs.kitty;
              "Mod+Q".close-window = {};
              "Mod+Space".spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call launcher toggle";

              "Alt+H".focus-column-left = {};
              "Alt+L".focus-column-right = {};
              "Alt+K".focus-window-up = {};
              "Alt+J".focus-window-down = {};
              
              "Alt+Shift+H".move-column-left = {};
              "Alt+Shift+L".move-column-right = {};
              "Alt+Shift+K".move-window-up = {};
              "Alt+Shift+J".move-window-down = {};

              "Alt+1".focus-workspace = 1;
              "Alt+2".focus-workspace = 2;
              "Alt+3".focus-workspace = 3;
              "Alt+4".focus-workspace = 4;
              "Alt+5".focus-workspace = 5;

              "Alt+ampersand".focus-workspace = 1;
              "Alt+eacute".focus-workspace = 2;
              "Alt+quotedbl".focus-workspace = 3;
              "Alt+apostrophe".focus-workspace = 4;
              "Alt+parenleft".focus-workspace = 5;

              "Alt+Shift+1".move-column-to-workspace = 1;
              "Alt+Shift+2".move-column-to-workspace = 2;
              "Alt+Shift+3".move-column-to-workspace = 3;
              "Alt+Shift+4".move-column-to-workspace = 4;
              "Alt+Shift+5".move-column-to-workspace = 5;

              "Alt+Shift+ampersand".move-column-to-workspace = 1;
              "Alt+Shift+eacute".move-column-to-workspace = 2;
              "Alt+Shift+quotedbl".move-column-to-workspace = 3;
              "Alt+Shift+apostrophe".move-column-to-workspace = 4;
              "Alt+Shift+parenleft".move-column-to-workspace = 5;

              "Alt+F".fullscreen-window = {};
              "Alt+M".maximize-column = {};
              "Alt+C".center-column = {};
              
              "Alt+Comma".consume-window-into-column = {};
              "Alt+Period".expel-window-from-column = {};
              "Alt+V".consume-or-expel-window-left = {};

              "Alt+R".switch-preset-column-width = {};
              "Alt+Minus".set-column-width = "-10%";
              "Alt+Equal".set-column-width = "+10%";
              "Alt+Shift+Minus".set-window-height = "-10%";
              "Alt+Shift+Equal".set-window-height = "+10%";

              "Mod+Shift+E".quit = {};

              "XF86AudioRaiseVolume".spawn-sh = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
              "XF86AudioLowerVolume".spawn-sh = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
              "XF86AudioMute".spawn-sh = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";

              "XF86MonBrightnessUp".spawn-sh = "brightnessctl set 5%+";
              "XF86MonBrightnessDown".spawn-sh = "brightnessctl set 5%-";
            };
          };
        };
      };

      flake = {
        nixosConfigurations.macbook = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };

          modules = [
            { nixpkgs.hostPlatform = "aarch64-linux"; }
            inputs.apple-silicon-support.nixosModules.apple-silicon-support
            ./hosts/laptop/default.nix

            inputs.home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.users.lena = import ./home/default.nix;
              home-manager.extraSpecialArgs = { inherit inputs; };
            }
          ];
        };
      };
    };
}
