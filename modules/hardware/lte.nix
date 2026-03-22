{ config, lib, pkgs, ... }:
let
  cfg = config.mySystem.hardware.lte;
in
{
  options.mySystem.hardware.lte = {
    enable = lib.mkEnableOption "LTE modem support";

    device = lib.mkOption {
      type = lib.types.str;
      default = "/dev/cdc-wdm0";
      description = "LTE modem device path";
    };

    enableAtBoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable LTE modem radio at boot";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      libmbim
      libqmi
    ];

    systemd.services.enable-lte = lib.mkIf cfg.enableAtBoot {
      description = "Enable LTE modem at boot";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/run/current-system/sw/bin/mbimcli -p -d ${cfg.device} -v --quectel-set-radio-state=on";
        RemainAfterExit = true;
      };
    };
  };
}
