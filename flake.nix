{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = { url = "github:nix-community/disko"; inputs.nixpkgs.follows = "nixpkgs"; };
    lanzaboote = { url = "github:nix-community/lanzaboote"; inputs.nixpkgs.follows = "nixpkgs"; };
    nixvirt = {
      url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
      disko,
      lanzaboote,
      nixvirt,
      ...
    }:

    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";

      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      mkHost = { name, modules ? [ ], specialArgs ? { } }:
        lib.nixosSystem {
          inherit system;
          specialArgs = { inherit pkgs-unstable; } // specialArgs;
          modules = [
            ./profiles/base.nix
            ./users/henner.nix
            home-manager.nixosModules.home-manager
            ./${name}/configuration.nix
          ] ++ modules;
        };

    in
    {
      devShells.${system}.meawhite-talos = import ./meawhite/talos/shell.nix {
        pkgs = nixpkgs.legacyPackages.${system};
      };

      packages.${system} = {
      meablack-installer =
        (lib.nixosSystem {
          inherit system;
          specialArgs = {
            targetSystem = self.nixosConfigurations.meablack;
            recoveryPassphraseFile =
              let file = builtins.getEnv "MEABLACK_RECOVERY_PASSPHRASE_FILE";
              in if file == "" then
                throw "Set MEABLACK_RECOVERY_PASSPHRASE_FILE and build with --impure; see meablack/README.md"
              else builtins.path { path = file; name = "meablack-recovery-passphrase"; };
          };
          modules = [ ./meablack/installer.nix ];
        }).config.system.build.isoImage;

      meawhite-installer =
        (lib.nixosSystem {
          inherit system;
          specialArgs = {
            targetSystem = self.nixosConfigurations.meawhite;
            recoveryPassphraseFile =
              let file = builtins.getEnv "MEAWHITE_RECOVERY_PASSPHRASE_FILE";
              in if file == "" then
                throw "Set MEAWHITE_RECOVERY_PASSPHRASE_FILE and build with --impure; see meawhite/README.md"
              else builtins.path { path = file; name = "meawhite-recovery-passphrase"; };
          };
          modules = [ ./meawhite/installer.nix ];
        }).config.system.build.isoImage;
      };

      nixosConfigurations = {
        meawhite = mkHost {
          name = "meawhite";
          specialArgs = { inherit nixvirt; };
          modules = [
            disko.nixosModules.disko
            lanzaboote.nixosModules.lanzaboote
            nixvirt.nixosModules.default
          ];
        };
        meawhite-secure = self.nixosConfigurations.meawhite.extendModules {
          modules = [ ./meawhite/secure-boot.nix ];
        };
        meablack = mkHost {
          name = "meablack";
          modules = [ disko.nixosModules.disko lanzaboote.nixosModules.lanzaboote ];
        };
        # Use after generating /var/lib/sbctl keys on the installed host.
        # The offline installer continues using the unsigned bootstrap profile.
        meablack-secure = self.nixosConfigurations.meablack.extendModules {
          modules = [ ./meablack/secure-boot.nix ];
        };
        meatab = mkHost { name = "meatab"; modules = [ ./profiles/workstation.nix ]; };
        meanovo = mkHost { name = "meanovo"; modules = [ ./profiles/workstation.nix ]; };
      };
    };
}
