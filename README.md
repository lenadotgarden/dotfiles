# NixOS config

Heyyyy this is my NixOS configuration!

## Hosts

| Host | Machine | Rebuild |
| --- | --- | --- |
| `macbook` | Apple Silicon MacBook (Asahi) | `sudo nixos-rebuild switch --flake .#macbook` |
| `thinkpad` | ThinkPad T495s | `sudo nixos-rebuild switch --flake .#thinkpad` |

- `core/` is shared by every NixOS host. Machine-specific settings (hostname, kernel, power, firmware) go in `hosts/<name>/`.
- Each host keeps its own `hardware-configuration.nix`. For a new machine: `cp /etc/nixos/hardware-configuration.nix hosts/<name>/`, then `git add` it (flakes only see tracked files).
- Per-machine niri values (keyboard variant, screen scale, touchpad) are the arguments of `mkNiri` in `flake.nix`.
