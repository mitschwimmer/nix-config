{ ... }:
{
  # br0 already connects enp129s0 to the LAN and retains the host's DHCP MAC.
  # cp-02 boots for DHCP/SSH; K3s waits for its runtime token file.
  services.kubernetesMicrovms = {
    enable = true;
    bridge = "br0";
    guests = [ "k8s-cp-01" "k8s-cp-02" ];
  };
}
