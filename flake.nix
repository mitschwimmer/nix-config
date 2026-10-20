{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      ...
    }@inputs:

    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";

      makeWorkstation =
        name:
        lib.nixosSystem {
          inherit system;
          specialArgs = {
            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              config = {
                allowUnfree = true;
              };
            };
          };
          modules = [
            ./${name}/configuration.nix
            ./common.nix
            ./users.nix
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "hm-backup";
                extraSpecialArgs = {
                  inherit (inputs) self;
                  pkgs-unstable = import nixpkgs-unstable {
                    inherit system;
                    config.allowUnfree = true;
                  };
                };
                users.henner = import ./home/henner;
              };
            }
          ];
        };

    in
    {
      nixosConfigurations = {
        mearock = makeWorkstation "mearock";
        meaxps = makeWorkstation "meaxps";
        meatab = makeWorkstation "meatab";
        meanovo = makeWorkstation "meanovo";
      };
    };
}
