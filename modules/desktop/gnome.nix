{ config, lib, pkgs, ... }:
let
  cfg = config.mySystem.desktop.gnome;
in
{
  options.mySystem.desktop.gnome = {
    enable = lib.mkEnableOption "GNOME desktop environment";
  };

  config = lib.mkIf cfg.enable {
    services.xserver.enable = true;
    services.xserver.desktopManager.gnome.enable = true;
  };
}
