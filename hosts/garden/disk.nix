{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/sda"; # boot volume OCI (virtio-scsi), 50 GB
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            extraArgs = [ "-L" "nixos-root" ];
            mountpoint = "/";
            mountOptions = [ "noatime" ];
          };
        };
      };
    };
  };

  # Second volume Oracle Cloud (Always Free, 50 Go, détachable
  # indépendamment du disque de boot) — /nix/store y est relocalisé
  # car le disque de boot (45 Go) est structurellement trop juste
  # pour les rebuilds complets du système (ex: bascule de channel).
  # Pas géré par disko (disque déjà formaté/peuplé à la main — on
  # ne veut surtout pas qu'un apply disko le reformate).
  #
  # IMPORTANT (cf. commit 30074cf qui avait dû revert ça) : ce mount
  # ne doit prendre effet qu'après un rsync FINAL de /nix/store fait
  # juste avant le reboot — aucun build ne doit avoir lieu entre ce
  # rsync et le reboot, sinon la génération active peut se retrouver
  # absente de la copie et le boot reste bloqué en emergency mode
  # (root est verrouillé, pas de shell de secours possible).
  fileSystems."/nix/store" = {
    device = "/dev/disk/by-uuid/56087f50-7a26-4939-953d-5901bd9ae179";
    fsType = "ext4";
    options = [ "noatime" ];
  };
}
