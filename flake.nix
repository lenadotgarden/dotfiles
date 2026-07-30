{
  description = "NixOS & Home Manager Configuration Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    apple-silicon-support.url = "github:tpwrules/nixos-apple-silicon";
    helium.url = "github:schembriaiden/helium-browser-nix-flake";
    antigravity-nix.url = "github:jacopone/antigravity-nix";
    fsel.url = "github:Mjoyufull/fsel";
    handy.url = "github:cjpais/Handy";
  };

  outputs = { self, nixpkgs, home-manager, apple-silicon-support, antigravity-nix, helium, fsel, handy, ... }@inputs:
  let
    system = "aarch64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    nixosConfigurations.macbook = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };

      modules = [
        apple-silicon-support.nixosModules.apple-silicon-support
        ./system/hardware-configuration.nix
        ./system/configuration.nix

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users.lena = import ./home/default.nix;
          home-manager.extraSpecialArgs = { inherit inputs; };
        }

        ({ config, lib, ... }: {
          environment.systemPackages = [
            antigravity-nix.packages.${system}.default
            antigravity-nix.packages.${system}.google-antigravity-cli
          ];
        })
      ];
    };
  };
}
