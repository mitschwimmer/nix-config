{ ... }:
let
  encrypted = name: mountpoint: {
    type = "luks";
    inherit name;
    settings = {
      allowDiscards = false;
      crypttabExtraOpts = [ "tpm2-device=auto" ];
    };
    content = { type = "filesystem"; format = "ext4"; inherit mountpoint; };
  };
  dataDisk = device: {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions.data = {
        size = "100%";
        type = "FD00";
        content = { type = "mdraid"; name = "meawhite-data"; };
      };
    };
  };
in {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-eui.002538a4514017bc";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = { size = "100%"; content = encrypted "cryptroot" "/"; };
          };
        };
      };
      data1 = dataDisk "/dev/disk/by-id/wwn-0x5000c5009dcaa25a";
      data2 = dataDisk "/dev/disk/by-id/wwn-0x5000c5009dccc120";
    };
    mdadm.meawhite-data = {
      type = "mdadm";
      level = 1;
      metadata = "1.2";
      content = encrypted "cryptdata" "/data";
    };
  };
}
