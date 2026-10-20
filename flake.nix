{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
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
