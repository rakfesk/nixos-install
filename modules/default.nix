{ ... }:
{
  imports = [
    ./base.nix
    ./audio.nix
    ./desktop/hyprland.nix
    ./desktop/gnome.nix
    ./virtualization.nix
    ./development.nix
    ./hardware/lte.nix
  ];
}
