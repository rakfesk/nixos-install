{ config, lib, pkgs, ... }:
let
  cfg = config.mySystem.development;
in
{
  options.mySystem.development = {
    enable = lib.mkEnableOption "development tools";

    editors = {
      vscode = lib.mkEnableOption "Visual Studio Code";
    };

    tools = {
      ansible = lib.mkEnableOption "Ansible automation";
      yocto = lib.mkEnableOption "Yocto/embedded development tools";
      databases = lib.mkEnableOption "database tools (MongoDB Compass, InfluxDB, Postman)";
    };

    hardware = {
      serial = lib.mkEnableOption "serial/USB debugging tools";
      wireshark = lib.mkEnableOption "Wireshark network analysis";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      git
      gh
      cmake
      binutils
    ]
    ++ lib.optionals cfg.editors.vscode [ vscode ]
    ++ lib.optionals cfg.tools.ansible [ ansible sshpass ]
    ++ lib.optionals cfg.tools.yocto [ multipath-tools cloud-utils uuu ]
    ++ lib.optionals cfg.tools.databases [ mongodb-compass influxdb2 postman ]
    ++ lib.optionals cfg.hardware.serial [ minicom usbutils libmbim libqmi ]
    ++ lib.optionals cfg.hardware.wireshark [ wireshark ];
  };
}
