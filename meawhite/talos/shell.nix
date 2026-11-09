{ pkgs }:
let
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
}
