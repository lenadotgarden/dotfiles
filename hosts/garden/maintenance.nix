{ config, lib, pkgs, ... }:

let
  docker = config.virtualisation.docker.package;
  bin = lib.makeBinPath [ docker pkgs.jq pkgs.zstd pkgs.coreutils pkgs.gnused pkgs.gnugrep pkgs.gawk pkgs.findutils pkgs.gnutar pkgs.sqlite ];

  # Images suivies automatiquement (mise à jour + test de santé + retour arrière).
  # Format : projet = "image:tag-suivi image:tag-suivi"
  autoProjects = {
    pihole = "pihole/pihole:latest klutchell/unbound:latest";
    syncthing = "syncthing/syncthing:latest";
    traefik = "traefik:v3.6";
    excalidash = "zimengxiong/excalidash-backend:latest zimengxiong/excalidash-frontend:latest";
  };
  # Images épinglées, signalées mais mises à jour à la main (migrations de base de données).
  manualProjects = {
    netbird = "netbirdio/netbird-server:latest netbirdio/dashboard:latest";
    calcom = "calcom/cal.com:v6.2.0-arm postgres:16 redis:7";
  };
  mkAssoc = name: attrs: "declare -A ${name}=(${lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "[${k}]=\"${v}\"") attrs)})";

  garden-update = pkgs.writeShellScriptBin "garden-update" ''
    set -uo pipefail
    export PATH=${bin}:$PATH
    export HOME=/root
    MODE="''${1:-apply}"            # apply | check
    ROOT=/srv/garden
    BK=/var/backups/garden/pre-update
    STAMP=$(date +%Y%m%d-%H%M%S)
    mkdir -p "$BK"
    ${mkAssoc "AUTO" autoProjects}
    ${mkAssoc "MANUAL" manualProjects}
    RC=0
    log() { echo "[garden-update] $*"; }

    upstream_digest() { docker buildx imagetools inspect --raw "$1" 2>/dev/null | sha256sum | awk '{print "sha256:"$1}'; }
    current_pin() {  # $1 = projet  $2 = repo (sans tag)
      grep -hE "image:[[:space:]]*$2[:@]" "$ROOT/$1/docker-compose.yml" | head -1 | sed -E 's/.*@(sha256:[0-9a-f]{64}).*/\1/'
    }
    wait_healthy() {  # $1 = projet ; max 240 s
      local end=$((SECONDS+240))
      while [ $SECONDS -lt $end ]; do
        sleep 10
        local bad
        bad=$(cd "$ROOT/$1" && docker compose ps -a --format json 2>/dev/null | jq -s 'flatten | map(select(.State!="running" or ((.Health//"")!="" and .Health!="healthy"))) | length')
        [ "''${bad:-1}" = "0" ] && return 0
      done
      return 1
    }

    report_manual() {
      for p in "''${!MANUAL[@]}"; do
        for track in ''${MANUAL[$p]}; do
          repo="''${track%:*}"; cur=$(current_pin "$p" "$repo"); new=$(upstream_digest "$track")
          [ -n "$new" ] && [ "$new" != "$cur" ] && log "MANUEL : mise à jour disponible pour $track ($p) -> à appliquer à la main"
        done
      done
    }

    update_project() {
      local p="$1" changes=()
      for track in ''${AUTO[$p]}; do
        local repo="''${track%:*}" cur new
        cur=$(current_pin "$p" "$repo"); new=$(upstream_digest "$track")
        if [ -z "$new" ]; then log "$p : digest amont introuvable pour $track (registre injoignable ?)"; continue; fi
        [ "$new" != "$cur" ] && changes+=("$track|$repo|$new")
      done
      [ ''${#changes[@]} -eq 0 ] && { log "$p : à jour"; return 0; }
      log "$p : ''${#changes[@]} mise(s) à jour disponible(s)"
      [ "$MODE" = check ] && return 0

      cd "$ROOT/$p" || return 1
      local name; name=$(docker compose config --format json | jq -r .name)
      cp -p docker-compose.yml "$BK/$p.compose.$STAMP"
      docker compose stop >/dev/null
      local vols; vols=$(docker volume ls -q --filter "label=com.docker.compose.project=$name")
      if [ -n "$vols" ]; then
        # shellcheck disable=SC2086
        tar --xattrs --acls --numeric-owner -C /var/lib/docker/volumes -cf - $vols | zstd -3 -q -o "$BK/$p-$STAMP.tar.zst"
      fi
      for c in "''${changes[@]}"; do
        IFS='|' read -r track repo new <<<"$c"
        sed -i -E "s|(image:[[:space:]]*)$repo:[^@[:space:]]*@sha256:[0-9a-f]{64}|\1$track@$new|" docker-compose.yml
        log "$p : $track -> $new"
      done
      if docker compose pull -q && docker compose up -d --remove-orphans && wait_healthy "$p"; then
        log "$p : OK"
        ls -1t "$BK"/"$p"-*.tar.zst 2>/dev/null | tail -n +4 | xargs -r rm -f
      else
        log "$p : ÉCHEC -> retour arrière"
        docker compose down >/dev/null 2>&1 || true
        cp -p "$BK/$p.compose.$STAMP" docker-compose.yml
        [ -f "$BK/$p-$STAMP.tar.zst" ] && zstd -dc "$BK/$p-$STAMP.tar.zst" | tar --xattrs --acls --numeric-owner -C /var/lib/docker/volumes -xf -
        docker compose up -d --remove-orphans
        wait_healthy "$p" && log "$p : retour arrière OK" || log "$p : retour arrière INCOMPLET, intervention requise"
        RC=1
      fi
    }

    for p in "''${!AUTO[@]}"; do update_project "$p"; done
    report_manual
    [ "$MODE" = apply ] && docker image prune -a -f --filter "until=336h" >/dev/null 2>&1
    exit $RC
  '';

  dumpScript = pkgs.writeShellScript "garden-dumps" ''
    set -euo pipefail
    export PATH=${bin}:$PATH
    d=/var/backups/garden/dumps; mkdir -p "$d"; chmod 700 /var/backups/garden "$d"
    docker exec calcom-database-1 sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' | zstd -q -o "$d/calcom.sql.zst.new"
    mv "$d/calcom.sql.zst.new" "$d/calcom.sql.zst"
    runuser -u postgres -- pg_dump matrix-synapse | zstd -q -o "$d/matrix-synapse.sql.zst.new"
    mv "$d/matrix-synapse.sql.zst.new" "$d/matrix-synapse.sql.zst"
    for f in netbird_netbird_data/store.db netbird_netbird_data/idp.db netbird_netbird_data/events.db excalidash_backend-data/dev.db; do
      src="/var/lib/docker/volumes/''${f%%/*}/_data/''${f#*/}"
      [ -f "$src" ] && sqlite3 "$src" ".backup '$d/''${f%%/*}-$(basename "$f")'"
    done
    docker exec -w /tmp pihole sh -c 'rm -f /tmp/*teleporter*.zip; pihole-FTL --teleporter >/dev/null 2>&1; ls /tmp/*teleporter*.zip' \
      | head -1 | xargs -r -I{} docker cp pihole:{} "$d/pihole-teleporter.zip" || echo "WARN: export Pi-hole ignoré"
  '';
in
{
  environment.systemPackages = [ garden-update ];

  ############################################################
  # Mises à jour NixOS hebdomadaires (sans redémarrage automatique)
  ############################################################
  system.autoUpgrade = {
    enable = true;
    flake = "/etc/nixos#garden";
    flags = [ "--update-input" "nixpkgs" "--update-input" "nixpkgs-unstable" "--no-write-lock-file" ];
    dates = "Sun 03:30";
    randomizedDelaySec = "15min";
    allowReboot = false;
    operation = "switch";
  };

  ############################################################
  # Mises à jour des conteneurs (digest épinglé, test de santé, retour arrière)
  ############################################################
  systemd.services.garden-update = {
    description = "Mise à jour des conteneurs (avec retour arrière)";
    after = [ "docker.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = { Type = "oneshot"; ExecStart = "${garden-update}/bin/garden-update apply"; TimeoutStartSec = "1h"; };
  };
  systemd.timers.garden-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "Sun 05:00"; RandomizedDelaySec = "20min"; Persistent = true; };
  };

  ############################################################
  # Sauvegardes chiffrées quotidiennes (restic) — dépôt local ; copie hors-serveur sur le Mac
  ############################################################
  services.restic.backups.garden = {
    initialize = true;
    repository = "/var/backups/restic";
    passwordFile = "/var/lib/garden/restic-password";
    paths = [ "/srv/garden" "/var/lib/radicale" "/var/lib/netbird" "/opt/vault" "/opt/syncthing" "/opt/unbound" "/etc/ssh" "/etc/nixos" "/var/backups/garden/dumps" "/var/lib/matrix-synapse" ];
    extraBackupArgs = [ "--exclude-caches" ];
    backupPrepareCommand = "${dumpScript}";
    pruneOpts = [ "--keep-daily 7" "--keep-weekly 5" "--keep-monthly 6" ];
    timerConfig = { OnCalendar = "03:00"; RandomizedDelaySec = "10min"; Persistent = true; };
  };
}
