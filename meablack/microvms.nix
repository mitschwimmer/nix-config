{ ... }:
{
  # Discover the wired NIC and its MAC on meablack before creating the bridge.
  # Host address: 192.168.1.28. Do not infer the NIC name from meawhite.
  services.kubernetesMicrovms = {
    enable = false;
    bridge = "br0";
    uplink = null;
    bridgeMac = null;
    guests = [ ];
  };
}
