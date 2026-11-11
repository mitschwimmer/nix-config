{ ... }:
{
  # br0 already connects enp129s0 to the LAN and retains the host's DHCP MAC.
  # First staged bootstrap: only k8s-cp-01. See docs/bootstrap.md.
  services.kubernetesMicrovms = {
    enable = true;
    bridge = "br0";
    guests = [ "k8s-cp-01" ];
  };
}
