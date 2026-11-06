#!/usr/bin/env python3
"""hermes-ctl — exécutant privilégié, PAS piloté par un LLM.

Tourne en tant que l'utilisateur `hermes-ctl` (jamais `hermes`). Surveille
une boîte aux lettres fichiers et exécute, via sudo, un ensemble fixe et
étroit de scripts root (cf modules/hermes/trust.nix) après avoir revérifié
lui-même le niveau de confiance courant — il ne fait jamais confiance à ce
qu'affirme la requête entrante.
"""
import json
import logging
import re
import subprocess
import time
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s hermes-ctl %(message)s")
log = logging.getLogger("hermes-ctl")

REQ_DIR = Path("/var/lib/hermes-ctl/requests")
RESP_DIR = Path("/var/lib/hermes-ctl/responses")
TRUST_FILE = Path("/etc/hermes/trust_level")

# Garder synchronisé avec hosts/garden/compose.nix et modules/hermes/trust.nix.
COMPOSE_PROJECTS = {"traefik", "netbird", "pihole", "syncthing", "calcom", "excalidash", "baserow", "mornye"}


def current_trust_level() -> int:
    try:
        return int(TRUST_FILE.read_text().strip())
    except (OSError, ValueError):
        return 0


def sudo_run(*args: str) -> tuple[bool, str]:
    try:
        r = subprocess.run(["sudo", "-n", *args], capture_output=True, text=True, timeout=120)
        out = (r.stdout or "") + (r.stderr or "")
        return r.returncode == 0, out.strip()
    except Exception as e:  # noqa: BLE001
        return False, str(e)


def handle(req: dict) -> dict:
    action = req.get("action")
    level = current_trust_level()

    if action == "status":
        ok, out = sudo_run("/run/current-system/sw/bin/garden-hermes-status")
        return {"ok": ok, "output": out}

    if action == "restart":
        name = req.get("name", "")
        if name not in COMPOSE_PROJECTS or not re.fullmatch(r"[a-z0-9-]+", name):
            return {"ok": False, "output": f"projet inconnu : {name}"}
        if level < 1:
            return {"ok": False, "output": "niveau de confiance insuffisant (>=1 requis)"}
        ok, out = sudo_run(f"/run/current-system/sw/bin/garden-hermes-restart-{name}")
        return {"ok": ok, "output": out}

    if action == "set_trust":
        new_level = req.get("level")
        if new_level not in (0, 1, 2):
            return {"ok": False, "output": "niveau invalide"}
        ok, out = sudo_run("/run/current-system/sw/bin/garden-hermes-set-trust", str(new_level))
        return {"ok": ok, "output": out}

    return {"ok": False, "output": f"action inconnue : {action}"}


def sweep_old_responses(max_age_s: int = 3600) -> None:
    now = time.time()
    for f in RESP_DIR.glob("*.json"):
        try:
            if now - f.stat().st_mtime > max_age_s:
                f.unlink()
        except OSError:
            pass


def main() -> None:
    REQ_DIR.mkdir(parents=True, exist_ok=True)
    RESP_DIR.mkdir(parents=True, exist_ok=True)
    log.info("hermes-ctl démarré")
    last_sweep = 0.0
    while True:
        for f in sorted(REQ_DIR.glob("*.json")):
            try:
                req = json.loads(f.read_text())
                result = handle(req)
                log.info("action=%s -> ok=%s", req.get("action"), result.get("ok"))
            except Exception as e:  # noqa: BLE001
                result = {"ok": False, "output": f"erreur hermes-ctl: {e}"}
            resp_path = RESP_DIR / f.name
            resp_path.write_text(json.dumps(result))
            resp_path.chmod(0o640)
            f.unlink(missing_ok=True)
        if time.time() - last_sweep > 300:
            sweep_old_responses()
            last_sweep = time.time()
        time.sleep(0.5)


if __name__ == "__main__":
    main()
