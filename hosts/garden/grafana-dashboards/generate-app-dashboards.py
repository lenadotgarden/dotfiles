#!/usr/bin/env python3
"""Génère un dashboard Grafana par application (native via process-exporter,
ou Docker via cAdvisor + la correspondance id->nom publiée par
garden-docker-names). Réexécuter ce script après avoir modifié la liste
d'apps ci-dessous, puis commit les fichiers générés."""

import json
import os

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# (uid_suffix, titre affiché, groupname process-exporter)
NATIVE_APPS = [
    ("postgresql", "PostgreSQL", "postgresql"),
    ("matrix-synapse", "Matrix Synapse", "matrix-synapse"),
    ("mas", "Matrix Authentication Service", "matrix-authentication-service"),
    ("navidrome", "Navidrome", "navidrome"),
    ("lidarr", "Lidarr", "lidarr"),
    ("prowlarr", "Prowlarr", "prowlarr"),
    ("qbittorrent", "qBittorrent", "qbittorrent"),
    ("flaresolverr", "FlareSolverr", "flaresolverr"),
    ("radicale", "Radicale", "radicale"),
    ("rclone-music", "rclone (montage musique)", "rclone-music-mount"),
    ("soularr", "Soularr", "soularr"),
    ("nginx", "nginx (well-known Matrix)", "nginx"),
]

# (uid_suffix, titre affiché, projet docker-compose)
DOCKER_APPS = [
    ("traefik", "Traefik", "traefik"),
    ("netbird-infra", "NetBird (serveur + dashboard)", "netbird"),
    ("pihole", "Pi-hole", "pihole"),
    ("syncthing-docker", "Syncthing", "syncthing"),
    ("calcom", "Cal.com", "calcom"),
    ("excalidash", "Excalidash", "excalidash"),
    ("baserow", "Baserow", "baserow"),
    ("mornye", "Mornye", "mornye"),
]


def native_dashboard(uid_suffix, title, groupname):
    uid = f"app-{uid_suffix}"
    return {
        "uid": uid,
        "title": f"App — {title}",
        "tags": ["app", "native"],
        "timezone": "browser",
        "schemaVersion": 41,
        "time": {"from": "now-6h", "to": "now"},
        "refresh": "30s",
        "panels": [
            {
                "id": 1,
                "type": "stat",
                "title": "État",
                "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
                "datasource": {"type": "prometheus", "uid": "Prometheus"},
                "targets": [{
                    "expr": f'namedprocess_namegroup_num_procs{{groupname="{groupname}"}}',
                    "legendFormat": "processus",
                }],
                "fieldConfig": {"defaults": {
                    "mappings": [
                        {"type": "range", "options": {"from": 0, "to": 0, "result": {"text": "ARRÊTÉ", "color": "red"}}},
                        {"type": "range", "options": {"from": 1, "to": 1000, "result": {"text": "EN COURS", "color": "green"}}},
                    ],
                    "thresholds": {"mode": "absolute", "steps": [{"value": None, "color": "green"}]},
                }, "overrides": []},
                "options": {"textMode": "value_and_name", "colorMode": "background"},
            },
            {
                "id": 2,
                "type": "timeseries",
                "title": "CPU",
                "gridPos": {"h": 8, "w": 18, "x": 6, "y": 0},
                "datasource": {"type": "prometheus", "uid": "Prometheus"},
                "targets": [{
                    "expr": f'rate(namedprocess_namegroup_cpu_seconds_total{{groupname="{groupname}"}}[5m])',
                    "legendFormat": "{{mode}}",
                }],
                "fieldConfig": {"defaults": {"unit": "percentunit"}, "overrides": []},
            },
            {
                "id": 3,
                "type": "timeseries",
                "title": "Mémoire",
                "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8},
                "datasource": {"type": "prometheus", "uid": "Prometheus"},
                "targets": [{
                    "expr": f'namedprocess_namegroup_memory_bytes{{groupname="{groupname}",memtype="resident"}}',
                    "legendFormat": "RSS",
                }],
                "fieldConfig": {"defaults": {"unit": "bytes"}, "overrides": []},
            },
        ],
    }


def docker_dashboard(uid_suffix, title, project):
    uid = f"app-{uid_suffix}"
    join = f'docker_container_info{{project="{project}"}}'
    return {
        "uid": uid,
        "title": f"App — {title} (Docker)",
        "tags": ["app", "docker"],
        "timezone": "browser",
        "schemaVersion": 41,
        "time": {"from": "now-6h", "to": "now"},
        "refresh": "30s",
        "panels": [
            {
                "id": 1,
                "type": "stat",
                "title": "Conteneurs actifs",
                "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
                "datasource": {"type": "prometheus", "uid": "Prometheus"},
                "targets": [{"expr": f'count({join})', "legendFormat": "conteneurs"}],
                "fieldConfig": {"defaults": {
                    "mappings": [
                        {"type": "range", "options": {"from": 0, "to": 0, "result": {"text": "ARRÊTÉ", "color": "red"}}},
                        {"type": "range", "options": {"from": 1, "to": 1000, "result": {"text": "EN COURS", "color": "green"}}},
                    ],
                }, "overrides": []},
                "options": {"textMode": "value_and_name", "colorMode": "background"},
            },
            {
                "id": 2,
                "type": "timeseries",
                "title": "CPU par conteneur",
                "gridPos": {"h": 8, "w": 18, "x": 6, "y": 0},
                "datasource": {"type": "prometheus", "uid": "Prometheus"},
                "targets": [{
                    "expr": (
                        f'sum by (name) ('
                        f'rate(container_cpu_usage_seconds_total{{id!="/"}}[5m]) '
                        f'* on(id) group_left(name) {join})'
                    ),
                    "legendFormat": "{{name}}",
                }],
                "fieldConfig": {"defaults": {"unit": "percentunit"}, "overrides": []},
            },
            {
                "id": 3,
                "type": "timeseries",
                "title": "Mémoire par conteneur",
                "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8},
                "datasource": {"type": "prometheus", "uid": "Prometheus"},
                "targets": [{
                    "expr": (
                        f'sum by (name) ('
                        f'container_memory_usage_bytes{{id!="/"}} '
                        f'* on(id) group_left(name) {join})'
                    ),
                    "legendFormat": "{{name}}",
                }],
                "fieldConfig": {"defaults": {"unit": "bytes"}, "overrides": []},
            },
            {
                "id": 4,
                "type": "timeseries",
                "title": "Réseau (reçu/envoyé)",
                "gridPos": {"h": 8, "w": 24, "x": 0, "y": 16},
                "datasource": {"type": "prometheus", "uid": "Prometheus"},
                "targets": [
                    {
                        "expr": (
                            f'sum by (name) (rate(container_network_receive_bytes_total{{id!="/"}}[5m]) '
                            f'* on(id) group_left(name) {join})'
                        ),
                        "legendFormat": "{{name}} - reçu",
                    },
                    {
                        "expr": (
                            f'sum by (name) (rate(container_network_transmit_bytes_total{{id!="/"}}[5m]) '
                            f'* on(id) group_left(name) {join})'
                        ),
                        "legendFormat": "{{name}} - envoyé",
                    },
                ],
                "fieldConfig": {"defaults": {"unit": "Bps"}, "overrides": []},
            },
        ],
    }


def main():
    for uid_suffix, title, groupname in NATIVE_APPS:
        d = native_dashboard(uid_suffix, title, groupname)
        path = os.path.join(OUT_DIR, f"apps/{uid_suffix}.json")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            json.dump(d, f, indent=2, ensure_ascii=False)

    for uid_suffix, title, project in DOCKER_APPS:
        d = docker_dashboard(uid_suffix, title, project)
        path = os.path.join(OUT_DIR, f"apps/{uid_suffix}.json")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            json.dump(d, f, indent=2, ensure_ascii=False)

    print(f"{len(NATIVE_APPS) + len(DOCKER_APPS)} dashboards générés dans {OUT_DIR}/apps/")


if __name__ == "__main__":
    main()
