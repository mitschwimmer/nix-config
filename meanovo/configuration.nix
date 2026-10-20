{
  config,
  pkgs,
  pkgs-unstable,
  ...
}:

{
  imports = [ ./hardware-configuration.nix ];
  system.stateVersion = "26.05";

  environment.systemPackages = with pkgs; [

  ];
  environment.etc."wireplumber/wireplumber.conf.d/51-audio.conf".text = ''
  monitor.alsa.rules = [
 # HDMI-Sinks deaktivieren
    {
      matches = [
        { node.name = "~alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__HDMI.*" }
      ]
      actions = {
        update-props = {
          node.disabled = true
        }
      }
    }
  # Geräte-Name
    {
      matches = [
        { device.name = "~alsa_card.pci-0000_00_1f.3.*" }
      ]
      actions = {
        update-props = {
          device.description = "Internal Audio"
        }
      }
    }
    # Kopfhörer-Ausgang umbenennen
    {
      matches = [
        { node.name = "~alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Headphones__sink" }
      ]
      actions = {
        update-props = {
          node.description = "Headphones"
          node.nick = "Headphones"
        }
      }
    }
  ]
'';
}
