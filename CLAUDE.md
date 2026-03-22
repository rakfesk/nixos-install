# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a NixOS installation automation repository that sets up a fully encrypted NixOS workstation with a single curl command. The target is a Hyprland-based Wayland desktop environment with development tools.

## Installation Command

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/rakfesk/nixos-install/refs/heads/init/install-nixos.sh)
```

## Architecture

The project uses flake-parts for modular configuration with feature toggles.

### Directory Structure

```
flake.nix                      # flake-parts entry point, exports nixosModules
modules/
  default.nix                  # Imports all feature modules
  base.nix                     # Core: boot, networking, users, shell, locale
  audio.nix                    # PipeWire audio
  desktop/
    hyprland.nix               # Hyprland + Wayland tools (greetd, waybar, etc.)
    gnome.nix                  # GNOME desktop fallback
  virtualization.nix           # Docker, libvirt/KVM
  development.nix              # Dev tools, editors, databases
  hardware/
    lte.nix                    # LTE modem systemd service
hosts/
  myhost.nix                   # Host config enabling desired features
vars.nix.tmp                   # Template for user variables
```

### Feature Module Options

Each module uses `mySystem.<feature>.enable` pattern:

- `mySystem.base` - Core system (hostname, timezone, user, etc.)
- `mySystem.audio` - PipeWire with optional 32-bit support
- `mySystem.desktop.hyprland` - Hyprland with optional greeter
- `mySystem.desktop.gnome` - GNOME desktop
- `mySystem.virtualization` - Container/VM support with `docker.enable` and `libvirt.enable` sub-options
- `mySystem.development` - Dev tools with sub-options: `editors.vscode`, `tools.ansible`, `tools.yocto`, `tools.databases`, `hardware.serial`, `hardware.wireshark`
- `mySystem.hardware.lte` - LTE modem with configurable device path

### Installation Flow

1. `install-nixos.sh` collects user inputs and LUKS passphrase
2. Partitions disk (GPT with EFI boot + LUKS-encrypted root)
3. Copies `flake.nix`, `modules/`, `hosts/` to `/mnt/etc/nixos/`
4. Substitutes variables into `vars.nix` from template
5. Runs `nixos-install --flake /mnt/etc/nixos#myhost`

## Testing Changes

To test configuration changes on a running NixOS system:
```bash
sudo nixos-rebuild switch --flake .#myhost
```

To test without switching (build only):
```bash
sudo nixos-rebuild build --flake .#myhost
```

To check flake syntax:
```bash
nix flake check
```

## Adding New Features

1. Create a new module in `modules/` with `options.mySystem.<feature>` and `config = lib.mkIf cfg.enable { ... }`
2. Import it in `modules/default.nix`
3. Enable it in `hosts/myhost.nix`
