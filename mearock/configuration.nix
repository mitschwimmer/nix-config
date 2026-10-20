{
  config,
  pkgs,
  pkgs-unstable,
  ...
}:

{
  imports = [ ./hardware-configuration.nix ];
  system.stateVersion = "25.11";
  networking.firewall = {
    enable = true;
    allowedTCPPortRanges = [
      {
        from = 7999;
        to = 8999;
      }
    ];
  };
  environment.systemPackages = [
    pkgs.python314Packages.huggingface-hub
    pkgs.nvtopPackages.amd
    (pkgs-unstable.llama-cpp-rocm)
  ];
}
