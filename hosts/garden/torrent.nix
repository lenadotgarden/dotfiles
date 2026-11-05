{ config, lib, pkgs, ... }:
{
  ############################################################
  # Prowlarr — gestionnaire d'indexeurs (torrent public + usenet si ajouté
  # plus tard), synchronise automatiquement vers Lidarr. Admin via NetBird.
  ############################################################
  services.prowlarr.enable = true;

  ############################################################
  # FlareSolverr — résout les protections Cloudflare de certains trackers
  # publics, utilisé par Prowlarr comme proxy pour ces indexeurs.
  ############################################################
  services.flaresolverr.enable = true;

  ############################################################
  # qBittorrent — client torrent, utilisé comme download client par Lidarr.
  # WebUI admin via NetBird uniquement ; seul le port de torrenting est ouvert.
  ############################################################
  services.qbittorrent = {
    enable = true;
    webuiPort = 8080;
    torrentingPort = 51413;
    extraArgs = [ "--confirm-legal-notice" ];
    serverConfig = {
      LegalNotice.Accepted = true;
      Preferences.WebUI.Port = 8080;
    };
  };
  networking.firewall.allowedTCPPorts = [ 51413 ];
  networking.firewall.allowedUDPPorts = [ 51413 ];

  # Autorise Traefik (br-proxy) à atteindre Prowlarr, qBittorrent, slskd,
  # Lidarr et Mornye côté hôte, pour leurs sous-domaines respectifs.
  networking.firewall.interfaces.br-proxy.allowedTCPPorts = [ 9696 8080 5030 8686 8300 ];
}
