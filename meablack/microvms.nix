{ ... }:
{
  # Observed 2026-11-14: eno1, 192.168.1.28/24, gateway 192.168.1.1.
  # Retain the uplink MAC on br0; first activation uses timed rollback.
  services.kubernetesMicrovms = {
    enable = true;
    bridge = "br0";
    uplink = "eno1";
    bridgeMac = "24:4b:fe:03:c4:69";
    guests = [ "k8s-cp-03" ];
  };
}
