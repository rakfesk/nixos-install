{ config, lib, pkgs, ... }:
let
  cfg = config.mySystem.audio;
in
{
  options.mySystem.audio = {
    enable = lib.mkEnableOption "PipeWire audio system";

    support32Bit = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable 32-bit ALSA support";
    };
  };

  config = lib.mkIf cfg.enable {
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = cfg.support32Bit;
      pulse.enable = true;
    };

    environment.systemPackages = with pkgs; [
      pavucontrol
      playerctl
    ];
  };
}
