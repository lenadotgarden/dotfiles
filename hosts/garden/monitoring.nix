{ config, lib, pkgs, ... }:

{
  ############################################################
  # Secrets (sops-nix) — mot de passe admin Grafana
  ############################################################
  sops.secrets."monitoring/grafana_admin_password" = {
    owner = "grafana";
    mode = "0400";
  };
  sops.secrets."monitoring/grafana_secret_key" = {
    owner = "grafana";
    mode = "0400";
  };

  ############################################################
  # node_exporter — état & perfs de l'hôte (CPU, RAM, disque, réseau...)
  ############################################################
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
    enabledCollectors = [
      "systemd"
      "processes"
      "diskstats"
      "filesystem"
      "meminfo"
      "netdev"
      "loadavg"
      "cpu"
      "time"
    ];
  };

  ############################################################
  # process-exporter — CPU/RAM par application (services NixOS natifs).
  # Les conteneurs Docker restants (traefik, pihole, calcom, baserow,
  # excalidash, mornye, netbird-server/dashboard) ne sont pas détaillés
  # individuellement ici : ajouter cAdvisor plus tard si besoin de ce niveau
  # de détail pour eux spécifiquement.
  ############################################################
  services.prometheus.exporters.process = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9256;
    settings.process_names = [
      { name = "postgresql"; comm = [ "postgres" ]; }
      { name = "matrix-synapse"; cmdline = [ "synapse\\.app\\.homeserver" ]; }
      { name = "matrix-authentication-service"; cmdline = [ "mas-cli" ]; }
      { name = "navidrome"; comm = [ "navidrome" ]; }
      { name = "lidarr"; cmdline = [ "Lidarr" ]; }
      { name = "prowlarr"; cmdline = [ "Prowlarr" ]; }
      { name = "qbittorrent"; comm = [ "qbittorrent-nox" ]; }
      { name = "flaresolverr"; cmdline = [ "flaresolverr" ]; }
      { name = "radicale"; cmdline = [ "radicale" ]; }
      { name = "rclone-music-mount"; cmdline = [ "rclone mount" ]; }
      { name = "soularr"; cmdline = [ "soularr\\.py" ]; }
      { name = "nginx"; comm = [ "nginx" ]; }
      { name = "netbird-client"; comm = [ "netbird" ]; }
      { name = "monitoring"; comm = [ "grafana" "prometheus" "node_exporter" "process-exporter" ]; }
      { name = "other"; cmdline = [ ".*" ]; }
    ];
  };

  ############################################################
  # Prometheus — scrape local uniquement (Grafana le requête en interne)
  ############################################################
  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9090;
    retentionTime = "30d";
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{ targets = [ "127.0.0.1:9100" ]; }];
      }
      {
        job_name = "process";
        static_configs = [{ targets = [ "127.0.0.1:9256" ]; }];
      }
      {
        job_name = "prometheus";
        static_configs = [{ targets = [ "127.0.0.1:9090" ]; }];
      }
      {
        # cAdvisor — métriques par conteneur (CPU/RAM/réseau) pour les apps
        # qui restent en Docker (traefik, pihole, syncthing, calcom,
        # excalidash, baserow, mornye, netbird-server/dashboard).
        job_name = "cadvisor";
        static_configs = [{ targets = [ "172.30.0.1:8081" ]; }];
      }
    ];
  };

  ############################################################
  # Grafana — accessible via grafana.lena.sh (Traefik, filtré par IP
  # NetBird, middleware "netbird-only") ou directement en
  # 100.79.103.184:3000. Importer les dashboards communautaires "Node
  # Exporter Full" (ID 1860) et "Process exporter" (ID 249) depuis
  # grafana.com une fois connecté.
  ############################################################
  networking.firewall.interfaces.br-proxy.allowedTCPPorts = [ 3000 ];

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
      };
      security.admin_user = "admin";
      security.admin_password = "$__file{${config.sops.secrets."monitoring/grafana_admin_password".path}}";
      security.secret_key = "$__file{${config.sops.secrets."monitoring/grafana_secret_key".path}}";
    };
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:9090";
          isDefault = true;
        }
      ];
      dashboards.settings.providers = [
        {
          name = "garden";
          options.path = ./grafana-dashboards;
        }
      ];
    };
  };
}
