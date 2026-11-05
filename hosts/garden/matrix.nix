{ config, lib, pkgs, ... }:

let
  # Secrets chiffrés avec sops (secrets/garden.yaml). Aucune valeur secrète dans le store Nix :
  # la config MAS ne contient que des chemins vers les fichiers déchiffrés dans /run/secrets.
  s = config.sops.secrets;
  masUser = "matrix-authentication-service";

  masConfig = (pkgs.formats.yaml { }).generate "mas-config.yaml" {
    http = {
      listeners = [
        {
          name = "web";
          resources = map (n: { name = n; }) [ "discovery" "human" "oauth" "compat" "graphql" "assets" ];
          binds = [{ address = "172.30.0.1:8010"; }]; # réseau proxy uniquement ; Traefik fait le TLS
          proxy_protocol = false;
        }
        {
          name = "internal";
          resources = [{ name = "health"; }];
          binds = [{ host = "localhost"; port = 8081; }];
          proxy_protocol = false;
        }
      ];
      trusted_proxies = [ "192.168.0.0/16" "172.16.0.0/12" "10.0.0.0/10" "127.0.0.1/8" "fd00::/8" "::1/128" ];
      public_base = "https://auth.lena.sh/";
      issuer = "https://auth.lena.sh/";
    };
    database = {
      uri = "postgresql:///${masUser}?host=/run/postgresql";
      max_connections = 10;
      min_connections = 0;
      connect_timeout = 30;
      idle_timeout = 600;
      max_lifetime = 1800;
    };
    email = {
      from = "\"Authentication Service\" <root@localhost>";
      reply_to = "\"Authentication Service\" <root@localhost>";
      transport = "blackhole";
    };
    secrets = {
      encryption_file = s."mas/encryption".path;
      keys = map (i: { key_file = s."mas/key${toString i}".path; }) [ 0 1 2 3 ];
    };
    passwords = {
      enabled = true;
      schemes = [
        { version = 1; algorithm = "bcrypt"; unicode_normalization = true; }
        { version = 2; algorithm = "argon2id"; }
      ];
      minimum_complexity = 3;
    };
    matrix = {
      kind = "synapse";
      homeserver = "lena.sh";
      secret_file = s."mas/matrix_secret".path;
      endpoint = "http://172.30.0.1:8008/";
    };
    clients = [{
      client_id = "0000000000000000000SYNAPSE";
      client_auth_method = "client_secret_basic";
      client_secret_file = s."mas/client_secret".path;
    }];
  };
in
{
  ############################################################
  # Secrets (sops-nix) : déchiffrés avec la clé SSH de l'hôte (/etc/ssh/ssh_host_ed25519_key)
  ############################################################
  sops.defaultSopsFile = ../../secrets/garden.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.secrets = {
    "synapse/macaroon_secret_key" = { owner = "matrix-synapse"; mode = "0400"; };
    "synapse/form_secret" = { owner = "matrix-synapse"; mode = "0400"; };
    # lu par Synapse (secret partagé avec MAS) : groupe matrix-synapse en lecture
    "mas/matrix_secret" = { owner = masUser; group = "matrix-synapse"; mode = "0440"; };
    "mas/encryption" = { owner = masUser; mode = "0400"; };
    "mas/client_secret" = { owner = masUser; mode = "0400"; };
    "mas/key0" = { owner = masUser; mode = "0400"; };
    "mas/key1" = { owner = masUser; mode = "0400"; };
    "mas/key2" = { owner = masUser; mode = "0400"; };
    "mas/key3" = { owner = masUser; mode = "0400"; };
  };

  # Fragment YAML rendu par sops-nix, chargé par Synapse via extraConfigFiles
  sops.templates."synapse-secrets.yaml" = {
    owner = "matrix-synapse";
    mode = "0400";
    content = ''
      macaroon_secret_key: "${config.sops.placeholder."synapse/macaroon_secret_key"}"
      form_secret: "${config.sops.placeholder."synapse/form_secret"}"
    '';
  };

  ############################################################
  # PostgreSQL
  ############################################################
  services.postgresql = {
    enable = true;
    initdbArgs = [ "--locale=C" "--encoding=UTF8" ]; # Synapse exige une collation C
    ensureDatabases = [ "matrix-synapse" masUser ];
    ensureUsers = [
      { name = "matrix-synapse"; ensureDBOwnership = true; }
      { name = masUser; ensureDBOwnership = true; }
    ];
  };

  ############################################################
  # Synapse (Matrix) — authentification déléguée à MAS
  ############################################################
  services.matrix-synapse = {
    enable = true;
    extraConfigFiles = [ config.sops.templates."synapse-secrets.yaml".path ];
    settings = {
      server_name = "lena.sh";
      public_baseurl = "https://matrix.lena.sh/";
      enable_registration = false; # comptes créés via mas-cli
      report_stats = false;
      max_upload_size = "50M";
      matrix_authentication_service = {
        enabled = true;
        endpoint = "http://172.30.0.1:8010/";
        secret_path = s."mas/matrix_secret".path;
      };
      # connexion par QR code (MSC4108 + canal hors bande MSC4388)
      experimental_features = {
        msc4108_enabled = true;
        msc4388_mode = "open";
      };
      database = {
        name = "psycopg2";
        args = {
          user = "matrix-synapse";
          database = "matrix-synapse";
          host = "/run/postgresql";
          cp_min = 5;
          cp_max = 10;
        };
      };
      # écoute uniquement sur le réseau proxy (br-proxy) ; Traefik fait le TLS
      listeners = [{
        port = 8008;
        bind_addresses = [ "172.30.0.1" ];
        type = "http";
        tls = false;
        x_forwarded = true;
        resources = [{ names = [ "client" "federation" ]; compress = false; }];
      }];
    };
  };

  systemd.services.matrix-synapse = {
    after = [ "docker.service" "garden-docker-network.service" "postgresql.service" ];
    requires = [ "garden-docker-network.service" ];
    wants = [ "docker.service" ];
  };

  ############################################################
  # Délégation : https://lena.sh/.well-known/matrix/{server,client} (JSON statique, réseau proxy seulement)
  ############################################################
  services.nginx = {
    enable = true;
    virtualHosts."matrix-wellknown" = {
      default = true;
      listen = [{ addr = "172.30.0.1"; port = 8009; }];
      locations."= /.well-known/matrix/server".extraConfig = ''
        default_type application/json;
        return 200 "{\"m.server\":\"matrix.lena.sh:443\"}";
      '';
      locations."= /.well-known/matrix/client".extraConfig = ''
        default_type application/json;
        add_header Access-Control-Allow-Origin "*";
        return 200 "{\"m.homeserver\":{\"base_url\":\"https://matrix.lena.sh\"},\"org.matrix.msc2965.authentication\":{\"issuer\":\"https://auth.lena.sh/\",\"account\":\"https://auth.lena.sh/account/\"}}";
      '';
    };
  };

  ############################################################
  # Matrix Authentication Service (auth.lena.sh) — OIDC, requis pour le QR code
  ############################################################
  users.users.${masUser} = {
    isSystemUser = true;
    group = masUser;
    description = "Matrix Authentication Service";
  };
  users.groups.${masUser} = { };

  systemd.services.matrix-authentication-service = {
    description = "Matrix Authentication Service (auth.lena.sh)";
    after = [ "postgresql.service" "matrix-synapse.service" "sops-nix.service" ];
    requires = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = masUser;
      Group = masUser;
      StateDirectory = "mas";
      StateDirectoryMode = "0750";
      ExecStart = "${pkgs.matrix-authentication-service}/bin/mas-cli -c ${masConfig} server";
      Restart = "on-failure";
      RestartSec = 10;
      # durcissement
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };
}
