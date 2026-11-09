{ nixosConfigurations }:
let
  workstations = [ "mearock" "meaxps" "meatab" "meanovo" ];
in
builtins.mapAttrs (name: host:
  let
    inherit (host) config;
    inherit (host.pkgs) lib;
    desktop = builtins.elem name workstations;
    home = config.home-manager.users.henner;
    packages = map lib.getName home.home.packages;
    require = condition: message: lib.assertMsg condition "${name}: ${message}";
  in
  assert require config.users.users.henner.isNormalUser "Henner account missing";
  assert require (builtins.elem "wheel" config.users.users.henner.extraGroups) "wheel membership missing";
  assert require (builtins.elem "networkmanager" config.users.users.henner.extraGroups == desktop) "NetworkManager group must be workstation-only";
  assert require (config.users.users.henner.openssh.authorizedKeys.keyFiles != [ ]) "Henner SSH keys missing";
  assert require (home.home.homeDirectory == "/home/henner") "Home Manager home directory changed";
  assert require (home.home.stateVersion == "26.05") "Home Manager state version changed";
  assert require (home.programs.bash.enable && home.programs.starship.enable && home.programs.tmux.enable) "shared terminal environment missing";
  assert require (!config.programs.tmux.enable) "tmux must be managed by Home Manager";
  assert require (home.programs.tmux.prefix == "M-`" && home.programs.tmux.baseIndex == 1) "tmux prefix and indices changed";
  assert require (builtins.all (p: builtins.elem p packages) [ "helix" "git" "delta" "ripgrep" ]) "shared CLI packages missing";
  assert require (home.xdg.configFile ? "helix/config.toml" && home.home.file ? ".gitconfig") "shared dotfiles missing";
  assert require (config.programs.niri.enable == desktop) "Niri profile mismatch";
  assert require (config.services.printing.enable == desktop) "printing profile mismatch";
  assert require (config.networking.networkmanager.enable == desktop) "NetworkManager profile mismatch";
  assert require (builtins.elem "foot" packages == desktop) "Foot must be workstation-only";
  assert require ((home.xdg.configFile ? "niri/config.kdl") == desktop) "Niri dotfiles profile mismatch";
  assert require ((home.xdg.configFile ? "quickshell/shell.qml") == desktop) "Quickshell dotfiles profile mismatch";
  assert require ((home.home.shellAliases ? prefer-light) == desktop) "desktop alias profile mismatch";
  assert require (config.security.sudo.wheelNeedsPassword) "sudo must continue requiring a password";
  assert require (config.services.openssh.settings.PermitRootLogin == (if desktop then "no" else "prohibit-password")) "root SSH policy changed";
  true
) nixosConfigurations
