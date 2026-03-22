{
  description = "My NixOS system with full disk encryption";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" ];

      flake = {
        nixosModules = {
          default = import ./modules;
          base = import ./modules/base.nix;
          desktop-hyprland = import ./modules/desktop/hyprland.nix;
          desktop-gnome = import ./modules/desktop/gnome.nix;
          virtualization = import ./modules/virtualization.nix;
          development = import ./modules/development.nix;
          hardware-lte = import ./modules/hardware/lte.nix;
          audio = import ./modules/audio.nix;
        };

        nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            self.nixosModules.default
            ./hosts/myhost.nix
          ];
        };
      };
    };
}
