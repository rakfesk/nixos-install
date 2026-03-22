{ config, lib, pkgs, ... }:
let
  cfg = config.mySystem.desktop.hyprland;
in
{
  options.mySystem.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland Wayland compositor";

    enableGreeter = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable tuigreet login greeter";
    };
  };

  config = lib.mkIf cfg.enable {
    services.xserver.enable = true;

    programs.hyprland.enable = true;

    services.greetd = lib.mkIf cfg.enableGreeter {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions ${pkgs.hyprland}/share/wayland-sessions";
          user = "greeter";
        };
      };
    };

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    environment.systemPackages = with pkgs; [
      kitty
      wofi
      hyprpanel
      hyprpaper
      hypridle
      hyprlock
      hyprshot
      waybar
      brightnessctl
      phinger-cursors
      libnotify
    ];
  };
}
