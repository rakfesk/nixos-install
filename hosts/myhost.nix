{ ... }:
{
  mySystem = {
    base.enable = true;

    audio.enable = true;

    desktop = {
      hyprland.enable = true;
      gnome.enable = true;
    };

    virtualization = {
      enable = true;
      docker.enable = true;
      libvirt.enable = true;
    };

    development = {
      enable = true;
      editors.vscode = true;
      tools.ansible = true;
      tools.yocto = true;
      tools.databases = true;
      hardware.serial = true;
      hardware.wireshark = true;
    };

    hardware.lte.enable = true;
  };
}
