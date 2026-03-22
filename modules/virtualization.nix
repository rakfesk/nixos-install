{ config, lib, pkgs, ... }:
let
  cfg = config.mySystem.virtualization;
  baseCfg = config.mySystem.base;
in
{
  options.mySystem.virtualization = {
    enable = lib.mkEnableOption "virtualization support";

    docker = {
      enable = lib.mkEnableOption "Docker container runtime";
    };

    libvirt = {
      enable = lib.mkEnableOption "libvirt/KVM virtualization";

      enableTPM = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable software TPM support for VMs";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = cfg.docker.enable;

    virtualisation.libvirtd = lib.mkIf cfg.libvirt.enable {
      enable = true;
      qemu.swtpm.enable = cfg.libvirt.enableTPM;
    };

    programs.virt-manager.enable = cfg.libvirt.enable;

    users.users.${baseCfg.user.name}.extraGroups = lib.mkIf baseCfg.enable (
      (lib.optional cfg.docker.enable "docker") ++
      (lib.optional cfg.libvirt.enable "libvirtd")
    );

    environment.systemPackages = with pkgs; [
      qemu
      qemu-user
    ] ++ lib.optionals cfg.docker.enable [
      dive
    ];
  };
}
