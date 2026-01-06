{ config, pkgs, ... }:
let
  vars = import ./vars.nix;
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  boot.binfmt.preferStaticEmulators = true;
 
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
 
  networking.hostName = vars.hostName; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Oslo";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  services.acpid.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions ${pkgs.hyprland}/share/wayland-sessions";
        user = "greeter";
      };
    };
  };
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "no";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "no";

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.hardware.bolt.enable = true;
  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${vars.user.name} = {
    isNormalUser = true;
    description = vars.user.description;
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" ];
    initialPassword = vars.user.initialPassword;
    packages = with pkgs; [
    #  thunderbird
    ];
  };
security.sudo.wheelNeedsPassword = false;
 users.defaultUserShell = pkgs.zsh;
 programs.zsh = {
    enable = true;
    ohMyZsh = {
      enable = true;
      plugins = [
        "git"
        "z"
      ];
      theme = "robbyrussell";
    };
  };
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
   fuse
   libGL
   xorg.libX11
];

  # Install firefox.
  programs.firefox.enable = true;
  
  programs.hyprland.enable = true;
  programs.virt-manager.enable = true;
  virtualisation.libvirtd.qemu.swtpm.enable = true;
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  virtualisation.docker = {
    enable = true;
  };
  virtualisation.libvirtd.enable = true;
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  wget
  kitty
  vscode
  git
  stow
  wofi
  hyprpanel
  hyprpaper
  hypridle
  hyprlock
  acpid
  phinger-cursors
  teleport_17
  dive
  fzf
  waybar
  htop
  vim
  brightnessctl
  #mako
  bc
  hyprshot
  pavucontrol
  libmbim
  libqmi
  keepassxc
  libnotify
  wireshark
  ncdu
  usbutils
  minicom
  gh
  jq
  cmake
  spotify
  playerctl
  ansible
  sshpass
  influxdb2
  qemu
  qemu-user
  multipath-tools #Yocto
  cloud-utils #Yocto
  mongodb-compass
  postman
  uuu #Yocto
  binutils #Ansible for ar
  ];

fonts.packages = with pkgs; [
  font-awesome
  iosevka
  material-design-icons
  nerd-fonts._0xproto
  nerd-fonts.droid-sans-mono
];

environment.sessionVariables.NIXOS_OZONE_WL = "1";
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

systemd.services.enable-lte = {
  description = "Enable LTE modem at boot";
  after = [ "network.target" ];
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "/run/current-system/sw/bin/mbimcli -p -d /dev/cdc-wdm0 -v --quectel-set-radio-state=on";
    RemainAfterExit = true;
  };
};

}