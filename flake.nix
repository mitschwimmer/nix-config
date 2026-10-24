{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = { url = "github:nix-community/disko"; inputs.nixpkgs.follows = "nixpkgs"; };
    lanzaboote = { url = "github:nix-community/lanzaboote"; inputs.nixpkgs.follows = "nixpkgs"; };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      disko,
      lanzaboote,
      ...
    }:

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
        meablack = lib.nixosSystem { inherit system; modules = [ disko.nixosModules.disko lanzaboote.nixosModules.lanzaboote ./black/configuration.nix ]; };
        mearock = makeWorkstation "mearock";
        meaxps = makeWorkstation "meaxps";
        meatab = makeWorkstation "meatab";
        meanovo = makeWorkstation "meanovo";
      };
    };
}
