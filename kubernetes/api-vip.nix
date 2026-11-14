{ lib, pkgs, name, node, ... }:

let
  # Run on the guest host stack, independently of Kubernetes/Cilium.
  apiReady = pkgs.writeShellScript "check-k3s-api-ready" ''
    set -eu
    # Only the local /readyz probe skips TLS verification. API clients do not.
    response="$("${lib.getExe pkgs.curl}" --silent --show-error --fail \
      --insecure --connect-timeout 1 --max-time 2 \
      https://127.0.0.1:6443/readyz)" || exit 1
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
