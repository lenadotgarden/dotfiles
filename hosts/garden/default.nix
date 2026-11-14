{ config, lib, pkgs, unstable, ... }:

let
  sshKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQChGh2cqz9B0pyPMjL3yZIp3n/oMLR5gZXfeGOtN0EJ4M/pQCvvaJ/wdsB17doN4BCdRjNzMIwk4cOt6afmPN0VtgY+md607Nre5g/ba1ceRYLaVJvJBam3Hy8EuPynvqoTOgHhpElb4AHQoXz3y9kyX/g5zgx5ipvK5s3y518uUsRHf8iuT36e1jcRODNWvUZsw7HTMC6lEiq/yTdL8Q9lDbDyujQK+OGWZuZREDWjYQft4SPKk84CDcOm2by4J+bbn5xmeh20gXRr1dbQ0rny9rTzjYbWO+k0WLCFo/EhpndQVO6Uzcvmn/SKsTSYb8ezp6qmS+PKzuU+qn2Mtv+z";
  # Clé perso de Léna (MacBook Pro), ajoutée 2026-11-07 pour scp/ssh direct
  # depuis son Mac (jusque-là seule la clé Oracle Cloud ci-dessus était
  # autorisée pour ubuntu).
  lenaMacKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDOIZw3DrQffv5jPSinILYK3eJ7Yr/zpaI0ThNaDOntVYoA1KtVrJIV+6RwIyED0M4ybLGkqX0QL5gfbJWO+A/4Cq3pfXgPyS8Nahyyb7W5SOSv9Fk53NvoFXivdXtT7jliNhfb6kOH6Po1Ug1kZ5NGI0fiyTPzIhD1Ctmy9/3fKj3wywHf1/xtKjYrcVus7TWCXdDqrFAYEWdDDgu+1JB2MMZUZrHmVT+ra9oD0aFwZCY3dnQxgvCVwoV9sXhiQgfxvJuPHP2hD+4d/aTqpNvBSlotdfyynSASjKZwh2Qnl4UFmyAsz2X+MjB1hOo+6VjDQDUdpj3fNGoqUdvTEH7NbsR1y2L/JZPTCjdGMxbEUJHKKOefimdi+xTHun4yqId9kOX5la+UyAvtou2L9eqJVlkbYWJ83K1gbDX0ytjoVkLBoCPqR26G515yCxax6iBB/pv9FlyPAQPnC5jda+0RK8R1EBUsgNv8wvFuyBYS+0p+0an3jw0u2Miirn34p777xx6bgblMxoFB0NGjXkWQEq6Ob8amjlCN3ZfA3sWpYWh6gf7KWpBQm9L1AYx0MzGKIwBMIwMNQuTXoy0ZWdsJAjxO4RIAGJpah38tJTi/mdyRLGW1qKrPhbMikHguE4LIq7Vm0QmNgRo1muJYEDF5iAX4W5cgJIWCnCByybLC6Q== alex.kalonkoat@gmail.com";
in
{
  system.stateVersion = "26.05";
  nixpkgs.hostPlatform = "aarch64-linux";

  ############################################################
  # Boot (UEFI aarch64, GRUB en mode "removable" -> pas de NVRAM)
  ############################################################
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
    configurationLimit = 8;
  };
  boot.loader.efi.canTouchEfiVariables = false;
  boot.initrd.availableKernelModules = [
    "virtio_pci" "virtio_scsi" "virtio_blk" "virtio_net" "sd_mod" "sr_mod"
    "xhci_pci" "usbhid" "nvme" "ahci"
  ];
  # console série OCI (ttyAMA0) + console VGA
  boot.kernelParams = [ "console=tty1" "console=ttyAMA0,115200" "nvme.shutdown_timeout=10" ];

  ############################################################
  # Réseau : DHCP Oracle (10.0.0.118/24), MTU 9000 comme Ubuntu
  ############################################################
  networking.hostName = "garden";
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.wait-online.enable = true;
  systemd.network.networks."10-oci" = {
    matchConfig.MACAddress = "02:00:17:02:b0:09";
    networkConfig.DHCP = "ipv4";
    linkConfig.MTUBytes = "9000";
    dhcpV4Config.RouteMetric = 100;
  };
  # DNS hôte : résolveur VCN Oracle puis publics (pas de systemd-resolved :
  # le port 53 du host est publié par Pi-hole/Docker).
  networking.nameservers = [ "169.254.169.254" "9.9.9.9" "1.1.1.1" ];
  services.resolved.enable = false;
  networking.timeServers = [ "169.254.169.254" ];
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  ############################################################
  # Utilisateurs
  ############################################################
  users.mutableUsers = false;
  users.groups.ubuntu.gid = 1001;
  users.groups.hermes.gid = 10000;
  users.users.hermes = {
    uid = 10000;
    group = "hermes";
    isSystemUser = true;
    description = "propriétaire du vault (Syncthing/Hermes)";
  };
  users.users.ubuntu = {
    isNormalUser = true;
    uid = 1001;
    group = "ubuntu";
    extraGroups = [ "wheel" "docker" "hermes" ];
    openssh.authorizedKeys.keys = [ sshKey lenaMacKey ];
  };
  security.sudo.wheelNeedsPassword = false; # identique à Ubuntu (clé SSH uniquement)

  ############################################################
  # SSH : 22 / 2222 / 8443 comme avant, clé uniquement, pas de root
  ############################################################
  services.openssh = {
    enable = true;
    ports = [ 22 2222 8443 ];
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      AllowUsers = [ "ubuntu" ];
      MaxAuthTries = 3;
      LoginGraceTime = 20;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
      # Réseau mesh (tailscale0, déjà "trusted" dans le firewall juste en
      # dessous ; NetBird utilisait 100.79.0.0/16, sous-réseau du même CGNAT
      # /10 que Tailscale) exempté des pénalités anti-scan OpenSSH : sinon
      # l'appli Hermes Desktop (connexions SSH répétées en peu de temps
      # pour établir sa passerelle) se fait jeter par PerSourcePenalties
      # ("Connection reset by peer" avant même le handshake).
      PerSourcePenaltyExemptList = "100.64.0.0/10";
    };
  };

  ############################################################
  # Pare-feu
  ############################################################
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
    "net.ipv4.ip_nonlocal_bind" = 1; # radicale écoute sur 172.30.0.1 (br-proxy)
    # durcissement noyau (sans impact docker/netbird)
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.tcp_syncookies" = 1;
  };
  networking.firewall = {
    enable = true;
    checkReversePath = "loose"; # docker + netbird/tailscale
    allowedTCPPorts = [ 22 2222 8443 ];
    allowedUDPPorts = [ 51820 41641 ]; # wireguard netbird (en pause) + tailscale
    trustedInterfaces = [ "wt0" "tailscale0" ];
    # Traefik (réseau proxy, passerelle 172.30.0.1) joint radicale / excalidash
    interfaces.br-proxy.allowedTCPPorts = [ 5232 3100 6767 8008 8009 8010 ];
    logRefusedConnections = false;
  };

  # Règles Docker reprises à l'identique de Ubuntu (iptables-persistent)
  systemd.services.garden-docker-firewall = {
    description = "Règles DOCKER-USER / FORWARD wt0 (DNS Pi-hole restreint)";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    partOf = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.iptables ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = ''
      set -e
      iptables -N DOCKER-USER 2>/dev/null || true
      iptables -F DOCKER-USER
      iptables -A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      for p in udp tcp; do
        iptables -A DOCKER-USER -s 172.19.0.0/16 -p $p --dport 53 -j ACCEPT
        # 100.64.0.0/10 : plage CGNAT partagée par Tailscale et NetBird
        # (celui-ci utilisait 100.79.0.0/16, un sous-réseau du même /10).
        iptables -A DOCKER-USER -s 100.64.0.0/10 -p $p --dport 53 -j ACCEPT
      done
      for p in udp tcp; do
        iptables -A DOCKER-USER -p $p --dport 53 -j DROP
      done
      iptables -A DOCKER-USER -j RETURN
      # wt0/tailscale0 <-> conteneurs
      for iface in wt0 tailscale0; do
        iptables -C FORWARD -o $iface -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null \
          || iptables -I FORWARD 1 -o $iface -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        iptables -C FORWARD -i $iface -j ACCEPT 2>/dev/null \
          || iptables -I FORWARD 1 -i $iface -j ACCEPT
      done
    '';
  };

  ############################################################
  # Docker (Dokploy / Swarm / Traefik / apps) — état recréé par restore.sh
  ############################################################
  # Données Docker sur le second volume (/dev/sdb) : le disque de boot
  # (45 Go) ne peut pas les contenir. /nix/store est monté en ro par
  # NixOS, donc on remonte le volume en rw à part et on bind-mount.
  fileSystems."/mnt/storage2" = {
    device = "/dev/disk/by-uuid/56087f50-7a26-4939-953d-5901bd9ae179";
    fsType = "ext4";
    options = [ "noatime" ];
  };
  fileSystems."/var/lib/docker" = {
    device = "/mnt/storage2/.garden-data/docker";
    fsType = "none";
    options = [ "bind" ];
    depends = [ "/mnt/storage2" ];
  };

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    daemon.settings = {
      log-driver = "json-file";
      log-opts = { max-size = "100m"; max-file = "3"; };
      userland-proxy = false; # préserve la vraie IP client pour ipAllowList/netbird-only de Traefik
    };
  };

  # Dépendance explicite sur le bind-mount externe (sinon rien n'empêche
  # dockerd de démarrer — ou de continuer à tourner — avant que
  # /var/lib/docker soit effectivement monté sur /mnt/storage2 : ça s'est
  # produit le 2026-11-14, où le bind s'est réactivé sous un dockerd déjà
  # lancé, masquant ses données sans le faire planter dans l'immédiat).
  systemd.services.docker = {
    after = [ "var-lib-docker.mount" ];
    requires = [ "var-lib-docker.mount" ];
  };


  ############################################################
  # NetBird client — EN PAUSE (2026-11-14, remplacé par Tailscale ci-dessous).
  # `enable = false` désactive déclarativement l'unit sans effacer la config
  # ni /var/lib/netbird : repasser à `true` pour la ranimer.
  ############################################################
  systemd.services.netbird = {
    enable = false;
    description = "NetBird mesh network client";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.iproute2 pkgs.iptables pkgs.nftables pkgs.openresolv pkgs.kmod ];
    environment.SYSTEMD_UNIT = "netbird";
    serviceConfig = {
      ExecStart = "${unstable.netbird}/bin/netbird service run --log-level info --daemon-addr unix:///var/run/netbird/sock --log-file /var/log/netbird/client.log";
      Restart = "always";
      RestartSec = 10;
      StateDirectory = "netbird";
      RuntimeDirectory = "netbird";
      LogsDirectory = "netbird";
    };
  };

  ############################################################
  # Tailscale (remplace NetBird, 2026-11-14)
  ############################################################
  services.tailscale.enable = true;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [ stdenv.cc.cc.lib zlib openssl curl ];

  environment.systemPackages = [ unstable.netbird unstable.claude-code ] ++ (with pkgs; [
    git vim curl wget htop rsync zstd tmux jq tcpdump dnsutils iproute2 lsof pciutils restic sqlite
  ]);

  ############################################################
  # Radicale (CalDAV/CardDAV) — même config qu'Ubuntu
  ############################################################
  services.radicale = {
    enable = true;
    settings = {
      server = { hosts = [ "172.30.0.1:5232" ]; max_connections = 20; };
      auth = {
        type = "htpasswd";
        htpasswd_filename = "/etc/radicale/users";
        htpasswd_encryption = "bcrypt";
      };
      # rights.file (pas nix-managé, comme /etc/radicale/users) : accès
      # owner_only pour chacun + règle explicite donnant à hermes un accès
      # RW sur tous ses calendriers (2026-11-08, pour qu'il
      # puisse les gérer directement en CalDAV).
      # NB (2026-11-08) : permissions "RW" (majuscule) seules ne suffisent
      # PAS pour créer un nouveau calendrier (MKCALENDAR exige "w" minuscule
      # sur la collection cible, cf. radicale/app/mkcol.py) — d'où "RWrw"
      # pour owner-only, sinon le client Mac Calendar se heurte à un 403
      # en boucle quand il essaie de créer une collection manquante.
      rights = { type = "from_file"; file = "/etc/radicale/rights"; };
      storage.filesystem_folder = "/var/lib/radicale/collections";
      logging.level = "info";
    };
  };
  systemd.services.radicale = {
    after = [ "docker.service" ];
    wants = [ "docker.service" ];
  };

  ############################################################
  # Divers
  ############################################################
  zramSwap.enable = true;
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" ];
    auto-optimise-store = true;
    allowed-users = [ "@wheel" ];
  };
  # 7j au lieu de 30j : disque Oracle fixe (45 Go, non redimensionnable),
  # marge structurellement serrée avec Grafana/Nextcloud/Matrix/Hermes/Docker.
  nix.gc = { automatic = true; dates = "daily"; options = "--delete-older-than 7d"; };
  services.journald.settings.Journal.SystemMaxUse = "500M";
  security.sudo.execWheelOnly = true;
}
