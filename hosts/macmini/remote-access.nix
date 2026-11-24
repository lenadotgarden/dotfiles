{ config, lib, pkgs, ... }:

# Remote access for Hermes (garden): SSH reachable only over the tailnet.
# Tailscale itself comes from core/packages.nix.
{
  services.openssh = {
    enable = true;
    openFirewall = false; # not exposed on the LAN/Wi-Fi, see tailscale0 below
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "lena" ];
    };
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 22 ];

  # Dedicated key for the Hermes agent on garden (private half: ~hermes/.ssh/id_ed25519_macmini).
  # Revoke by deleting this line.
  users.users.lena.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEy22i53U/pJdKB3v1K9HvQpTBVkQspIRUqW5DH0m+/i hermes@garden (macmini)"
  ];
}
