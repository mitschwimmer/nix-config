{ ... }:
{
  # br0 already connects enp129s0 to the LAN and retains the host's DHCP MAC.
  # Enable k8s-test first; see docs/bootstrap.md before activating any guests.
  services.kubernetesMicrovms = {
    enable = false;
    bridge = "br0";
    guests = [ ];
  };
}
