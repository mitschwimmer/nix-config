{ config, lib, pkgs, name, node, ... }:

let
  # Run on the guest host stack, independently of Kubernetes/Cilium.
  apiReady = pkgs.writeShellScript "check-k3s-api-ready" ''
    set -eu
    # K3s denies anonymous /readyz requests (HTTP 401). Use its runtime
    # admin kubeconfig without copying credentials into the Nix store.
    response="$("${config.services.k3s.package}/bin/k3s" kubectl \
      --kubeconfig=/etc/rancher/k3s/k3s.yaml \
      --server=https://127.0.0.1:6443 \
      --request-timeout=2s get --raw=/readyz 2>/dev/null)" || exit 1
    test "$response" = ok
  '';
  priority =
    if name == "k8s-cp-01" then 150
    else if name == "k8s-cp-03" then 140
    else 130;
in
lib.mkIf (node.role == "server") {
  # Also make the readiness probe easy to run by hand during failover tests.
  environment.systemPackages = [ pkgs.curl ];
  services.keepalived = {
    enable = true;
    enableScriptSecurity = true;
    # Opens IP protocol 112 (VRRP) on the guests.
    openFirewall = true;
    vrrpScripts.check_k3s_api = {
      script = "${apiReady}";
      interval = 3;
      timeout = 3;
      rise = 2;
      fall = 2;
      weight = 0; # A failed readiness probe forces VRRP FAULT.
      user = "root";
      extraConfig = "init_fail";
    };
    vrrpInstances.k3s_api = {
      state = "BACKUP";
      interface = "lan0";
      # Verify that VRID 110 is unused on the LAN before rollout.
      virtualRouterId = 110;
      inherit priority;
      noPreempt = true;
      # Multicast VRRP avoids guessing cp-02/cp-03 DHCP reservations.
      # A /32 does not add a second connected /24 LAN route.
      virtualIps = [ { addr = "192.168.1.110/32"; dev = "lan0"; } ];
      trackScripts = [ "check_k3s_api" ];
    };
  };
}
