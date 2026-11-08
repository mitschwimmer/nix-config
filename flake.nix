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
      devShells.${system}.meawhite-talos =
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # Match the Talos node rather than relying on nixpkgs' moving version.
          talosctlPinned = pkgs.runCommand "talosctl-1.14.5" { } ''
            install -Dm755 ${pkgs.fetchurl {
              url = "https://github.com/siderolabs/talos/releases/download/v1.14.5/talosctl-linux-amd64";
              sha256 = "ff432b68986709e6b69c563a08a2ced4232d5196b0dccd6d2e783e9d714d7d7d";
            }} "$out/bin/talosctl"
          '';
          ciliumCliPinned = pkgs.runCommand "cilium-cli-0.20.2" { } ''
            mkdir -p "$out/bin"
            tar -xzf ${pkgs.fetchurl {
              url = "https://github.com/cilium/cilium-cli/releases/download/v0.20.2/cilium-linux-amd64.tar.gz";
              sha256 = "b7224a62bfed0e84f1a84567d274fefc5017df76a936e067c42012bb7fc30856";
            }} -C "$out/bin" cilium
            chmod 755 "$out/bin/cilium"
          '';
        in
        pkgs.mkShell {
          packages = with pkgs; [
            kubernetes-helm
            kubectl
            talosctlPinned
            ciliumCliPinned
          ];
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
        meawhite = lib.nixosSystem {
          inherit system;
          specialArgs = { inherit nixvirt; };
          modules = [
            disko.nixosModules.disko
            lanzaboote.nixosModules.lanzaboote
            nixvirt.nixosModules.default
            ./meawhite/configuration.nix
          ];
        };
        meawhite-secure = self.nixosConfigurations.meawhite.extendModules {
          modules = [ ./meawhite/secure-boot.nix ];
        };
        meablack = lib.nixosSystem { inherit system; modules = [ disko.nixosModules.disko lanzaboote.nixosModules.lanzaboote ./meablack/configuration.nix ]; };
        # Use after generating /var/lib/sbctl keys on the installed host.
        # The offline installer continues using the unsigned bootstrap profile.
        meablack-secure = self.nixosConfigurations.meablack.extendModules {
          modules = [ ./meablack/secure-boot.nix ];
        };
        mearock = makeWorkstation "mearock";
        meaxps = makeWorkstation "meaxps";
        meatab = makeWorkstation "meatab";
        meanovo = makeWorkstation "meanovo";
      };
    };
}
