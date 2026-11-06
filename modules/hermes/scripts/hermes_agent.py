#!/usr/bin/env python3
"""Hermes — agent résident sur garden.

Un seul process, tourne en tant que l'utilisateur système `hermes` (aucun
sudo, aucun accès docker). Pont Telegram + boucle d'appel direct à
l'API Deepseek (compatible OpenAI) avec quelques outils fixes. Les
actions privilégiées (statut docker, redémarrage de service, changement
de niveau de confiance) ne sont JAMAIS exécutées ici : une requête est
déposée dans une boîte aux lettres fichiers lue par le service séparé
`hermes-ctl` (utilisateur dédié, seul à avoir les droits sudo étroits).
"""
import json
import logging
import os
import re
import time
import uuid
from pathlib import Path

import requests
from telegram import Update
from telegram.ext import Application, ContextTypes, MessageHandler, filters

logging.basicConfig(level=logging.INFO, format="%(asctime)s hermes-agent %(message)s")
log = logging.getLogger("hermes-agent")
# httpx/telegram loguent l'URL complète des requêtes, TOKEN INCLUS, en INFO :
# ça finirait en clair dans le journal systemd sinon.
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)

WORKSPACE = Path(os.environ.get("HERMES_WORKSPACE", "/opt/vault"))
MEMORY_DIR = WORKSPACE / "6 Archive" / "Hermes" / "sessions"
JOURNAL_FILE = WORKSPACE / "6 Archive" / "Hermes" / "journal.md"
MAILBOX_REQ = Path("/var/lib/hermes-ctl/requests")
MAILBOX_RESP = Path("/var/lib/hermes-ctl/responses")
TRUST_FILE = Path("/etc/hermes/trust_level")
AGENTS_MD = Path("/etc/hermes/AGENTS.md")

TELEGRAM_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
ALLOWED_CHAT_ID = int(os.environ["TELEGRAM_ALLOWED_CHAT_ID"])
DEEPSEEK_API_KEY = os.environ["DEEPSEEK_API_KEY"]
DEEPSEEK_URL = "https://api.deepseek.com/chat/completions"
MODEL = "deepseek-chat"

TOOLS = [
    {"type": "function", "function": {
        "name": "read_file", "description": "Lit un fichier du vault (chemin relatif à la racine du vault).",
        "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]},
    }},
    {"type": "function", "function": {
        "name": "write_file", "description": "Écrit (crée ou remplace) un fichier du vault.",
        "parameters": {"type": "object", "properties": {
            "path": {"type": "string"}, "content": {"type": "string"},
        }, "required": ["path", "content"]},
    }},
    {"type": "function", "function": {
        "name": "list_dir", "description": "Liste un dossier du vault (chemin relatif, '' pour la racine).",
        "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]},
    }},
    {"type": "function", "function": {
        "name": "status", "description": "Statut en lecture seule du serveur (services docker, niveau de confiance).",
        "parameters": {"type": "object", "properties": {}},
    }},
    {"type": "function", "function": {
        "name": "restart_service",
        "description": "Redémarre un service docker-compose déjà connu du serveur (niveau de confiance >= 1 requis).",
        "parameters": {"type": "object", "properties": {"name": {"type": "string"}}, "required": ["name"]},
    }},
    {"type": "function", "function": {
        "name": "request_promotion",
        "description": "Demande à Léna de faire passer ton niveau de confiance à `level`, avec une raison concrète. "
                        "Elle seule peut confirmer sur Telegram ; rien ne change avant sa réponse explicite.",
        "parameters": {"type": "object", "properties": {
            "level": {"type": "integer"}, "reason": {"type": "string"},
        }, "required": ["level", "reason"]},
    }},
]


def _safe_path(rel: str) -> Path:
    p = (WORKSPACE / rel).resolve()
    if not str(p).startswith(str(WORKSPACE.resolve())):
        raise ValueError("chemin hors du vault")
    return p


def journal(line: str) -> None:
    JOURNAL_FILE.parent.mkdir(parents=True, exist_ok=True)
    with JOURNAL_FILE.open("a", encoding="utf-8") as f:
        f.write(f"- {time.strftime('%Y-%m-%d %H:%M:%S')} — {line}\n")


def mailbox_call(action: str, timeout: float = 15.0, **fields) -> dict:
    MAILBOX_REQ.mkdir(parents=True, exist_ok=True)
    req_id = str(uuid.uuid4())
    payload = {"id": req_id, "action": action, **fields}
    (MAILBOX_REQ / f"{req_id}.json").write_text(json.dumps(payload))
    resp_path = MAILBOX_RESP / f"{req_id}.json"
    deadline = time.time() + timeout
    while time.time() < deadline:
        if resp_path.exists():
            try:
                return json.loads(resp_path.read_text())
            except (OSError, json.JSONDecodeError):
                pass
        time.sleep(0.3)
    return {"ok": False, "output": "hermes-ctl n'a pas répondu à temps"}


def current_trust_level() -> int:
    try:
        return int(TRUST_FILE.read_text().strip())
    except (OSError, ValueError):
        return 0


# --- Exécution des outils ---------------------------------------------------

def tool_read_file(path):
    try:
        return _safe_path(path).read_text(encoding="utf-8")[:20000]
    except Exception as e:  # noqa: BLE001
        return f"erreur: {e}"


def tool_write_file(path, content):
    try:
        p = _safe_path(path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content, encoding="utf-8")
        journal(f"écrit `{path}`")
        return "ok"
    except Exception as e:  # noqa: BLE001
        return f"erreur: {e}"


def tool_list_dir(path):
    try:
        p = _safe_path(path)
        return "\n".join(sorted(x.name + ("/" if x.is_dir() else "") for x in p.iterdir()))
    except Exception as e:  # noqa: BLE001
        return f"erreur: {e}"


def tool_status(**_):
    r = mailbox_call("status")
    return r.get("output", json.dumps(r))


def tool_restart_service(name, **_):
    r = mailbox_call("restart", name=name)
    journal(f"demande de redémarrage `{name}` -> {r.get('ok')}")
    return r.get("output", json.dumps(r))


# pending_promotion: état en mémoire, PAS dans un outil rappelable par le
# modèle — seule la vérification déterministe du texte reçu de Léna peut
# la faire aboutir (cf handle_message).
PENDING_PROMOTION = {}


def tool_request_promotion(level, reason, chat_id):
    PENDING_PROMOTION[chat_id] = {"level": level, "reason": reason}
    journal(f"a demandé le niveau {level} : {reason}")
    return (f"Demande envoyée à Léna (niveau {level} : {reason}). "
            f"En attente de sa confirmation explicite — ne redemande pas avant sa réponse.")


TOOL_IMPL = {
    "read_file": lambda a, chat_id: tool_read_file(a["path"]),
    "write_file": lambda a, chat_id: tool_write_file(a["path"], a["content"]),
    "list_dir": lambda a, chat_id: tool_list_dir(a.get("path", "")),
    "status": lambda a, chat_id: tool_status(),
    "restart_service": lambda a, chat_id: tool_restart_service(a["name"]),
    "request_promotion": lambda a, chat_id: tool_request_promotion(a["level"], a["reason"], chat_id),
}


# --- Boucle Deepseek ---------------------------------------------------------

def load_history(chat_id: int) -> list:
    f = MEMORY_DIR / f"{chat_id}.json"
    if f.exists():
        try:
            return json.loads(f.read_text())
        except (OSError, json.JSONDecodeError):
            pass
    return []


def save_history(chat_id: int, history: list) -> None:
    MEMORY_DIR.mkdir(parents=True, exist_ok=True)
    (MEMORY_DIR / f"{chat_id}.json").write_text(json.dumps(history[-60:]))


def system_prompt() -> str:
    base = AGENTS_MD.read_text(encoding="utf-8") if AGENTS_MD.exists() else "Tu es Hermes."
    return base + f"\n\nNiveau de confiance actuel : {current_trust_level()}."


def deepseek_chat(messages: list) -> dict:
    resp = requests.post(
        DEEPSEEK_URL,
        headers={"Authorization": f"Bearer {DEEPSEEK_API_KEY}", "Content-Type": "application/json"},
        json={"model": MODEL, "messages": messages, "tools": TOOLS, "tool_choice": "auto"},
        timeout=120,
    )
    resp.raise_for_status()
    return resp.json()["choices"][0]["message"]


def run_turn(chat_id: int, user_text: str) -> str:
    history = load_history(chat_id)
    messages = [{"role": "system", "content": system_prompt()}] + history + [{"role": "user", "content": user_text}]

    for _ in range(8):  # garde-fou anti-boucle d'outils
        msg = deepseek_chat(messages)
        messages.append(msg)
        calls = msg.get("tool_calls") or []
        if not calls:
            history.append({"role": "user", "content": user_text})
            history.append({"role": "assistant", "content": msg.get("content", "")})
            save_history(chat_id, history)
            return msg.get("content", "")
        for call in calls:
            name = call["function"]["name"]
            try:
                args = json.loads(call["function"]["arguments"] or "{}")
            except json.JSONDecodeError:
                args = {}
            impl = TOOL_IMPL.get(name)
            result = impl(args, chat_id) if impl else f"outil inconnu: {name}"
            messages.append({"role": "tool", "tool_call_id": call["id"], "content": str(result)})
    return "Désolé, je me suis perdu dans trop d'étapes d'outils — reformule ta demande."


# --- Telegram -----------------------------------------------------------------

async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    chat_id = update.effective_chat.id
    text = (update.message.text or "").strip()

    if chat_id != ALLOWED_CHAT_ID:
        log.warning("message ignoré d'un chat non autorisé: %s", chat_id)
        return

    pending = PENDING_PROMOTION.get(chat_id)
    if pending is not None:
        if re.match(r"^\s*oui\b", text, re.IGNORECASE):
            r = mailbox_call("set_trust", level=pending["level"])
            del PENDING_PROMOTION[chat_id]
            if r.get("ok"):
                journal(f"promu au niveau {pending['level']} (confirmé par Léna)")
                await update.message.reply_text(f"Niveau de confiance passé à {pending['level']}. Merci de ta confiance 🪽")
            else:
                await update.message.reply_text(f"Échec de la mise à jour : {r.get('output')}")
            return
        if re.match(r"^\s*non\b", text, re.IGNORECASE):
            del PENDING_PROMOTION[chat_id]
            await update.message.reply_text("Ok, je reste à ce niveau.")
            return
        # tout autre message : on laisse tomber la demande en attente et on continue normalement
        del PENDING_PROMOTION[chat_id]

    reply = run_turn(chat_id, text)
    if len(reply) > 3800:
        reply = reply[:3800] + "…"
    await update.message.reply_text(reply or "…")


def main() -> None:
    app = Application.builder().token(TELEGRAM_TOKEN).build()
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    log.info("hermes-agent démarré, chat autorisé=%s", ALLOWED_CHAT_ID)
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
