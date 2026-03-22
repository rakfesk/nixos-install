{ config, lib, pkgs, vars, ... }:
let
  cfg = config.mySystem.base;
in
{
  options.mySystem.base = {
    enable = lib.mkEnableOption "base system configuration";

    hostname = lib.mkOption {
      type = lib.types.str;
      default = vars.hostName;
      description = "System hostname";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "Europe/Oslo";
      description = "System timezone";
    };

    locale = lib.mkOption {
      type = lib.types.str;
      default = "en_GB.UTF-8";
      description = "System locale";
    };

    keyboardLayout = lib.mkOption {
      type = lib.types.str;
      default = "no";
      description = "Keyboard layout";
    };

    user = {
      name = lib.mkOption {
        type = lib.types.str;
        default = vars.user.name;
        description = "Primary user name";
      };

      description = lib.mkOption {
        type = lib.types.str;
        default = vars.user.description;
        description = "User description/full name";
      };

      initialPassword = lib.mkOption {
        type = lib.types.str;
        default = vars.user.initialPassword;
        description = "Initial password for the user";
      };

      extraGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "networkmanager" "wheel" ];
        description = "Extra groups for the user";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelPackages = pkgs.linuxPackages_latest;
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
    boot.binfmt.preferStaticEmulators = true;

    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    networking.hostName = cfg.hostname;
    networking.networkmanager.enable = true;

    time.timeZone = cfg.timezone;
    i18n.defaultLocale = cfg.locale;

    services.xserver.xkb = {
      layout = cfg.keyboardLayout;
      variant = "";
    };
    console.keyMap = cfg.keyboardLayout;

    services.acpid.enable = true;
    services.printing.enable = true;
    services.hardware.bolt.enable = true;

    users.users.${cfg.user.name} = {
      isNormalUser = true;
      description = cfg.user.description;
      extraGroups = cfg.user.extraGroups;
      initialPassword = cfg.user.initialPassword;
    };

    security.sudo.wheelNeedsPassword = false;
    users.defaultUserShell = pkgs.zsh;

    programs.zsh = {
      enable = true;
      ohMyZsh = {
        enable = true;
        plugins = [ "git" "z" ];
        theme = "robbyrussell";
      };
    };

    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      fuse
      libGL
      xorg.libX11
    ];

    programs.firefox.enable = true;
    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = with pkgs; [
      wget
      git
      stow
      fzf
      htop
      vim
      bc
      jq
      ncdu
      usbutils
    ];

    fonts.packages = with pkgs; [
      font-awesome
      iosevka
      material-design-icons
      nerd-fonts._0xproto
      nerd-fonts.droid-sans-mono
    ];

    system.stateVersion = "25.11";
  };
}
