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
            input.keyboard.xkb.layout = "fr"; 
            input.keyboard.xkb.variant = "mac";

            input.touchpad.click-method = "clickfinger";
            input.touchpad.natural-scroll = {};

            outputs."eDP-1".scale = 1.5625;

            layout.gaps = 5;

            spawn-at-startup = [
              (lib.getExe self'.packages.myNoctalia)
            ];
            binds = {
              "Mod+Return".spawn-sh = lib.getExe pkgs.kitty;
              "Mod+Q".close-window = {};
              "Mod+S".spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call launcher toggle";
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
