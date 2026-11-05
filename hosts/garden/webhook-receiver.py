#!/usr/bin/env python3
"""Minimal GitHub webhook receiver: verifies the HMAC signature, and on a
push to refs/heads/main triggers an immediate `comin fetch` instead of
waiting for comin's own polling interval."""

import hashlib
import hmac
import json
import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SECRET_FILE = os.environ["GITHUB_WEBHOOK_SECRET_FILE"]
COMIN_BIN = os.environ.get("COMIN_BIN", "comin")


def load_secret() -> bytes:
    with open(SECRET_FILE, "rb") as f:
        return f.read().strip()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        sys.stderr.write("%s\n" % (fmt % args))

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)

        signature = self.headers.get("X-Hub-Signature-256", "")
        expected = "sha256=" + hmac.new(load_secret(), body, hashlib.sha256).hexdigest()
        if not hmac.compare_digest(signature, expected):
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b"invalid signature")
            return

        event = self.headers.get("X-GitHub-Event", "")
        if event == "ping":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"pong")
            return

        if event != "push":
            self.send_response(204)
            self.end_headers()
            return

        try:
            payload = json.loads(body)
        except ValueError:
            self.send_response(400)
            self.end_headers()
            return

        if payload.get("ref") != "refs/heads/main":
            self.send_response(204)
            self.end_headers()
            self.wfile.write(b"ignored: not main")
            return

        result = subprocess.run([COMIN_BIN, "fetch"], capture_output=True, text=True)
        if result.returncode != 0:
            self.log_message("comin fetch failed: %s", result.stderr)
            self.send_response(502)
            self.end_headers()
            self.wfile.write(b"comin fetch failed")
            return

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"fetch triggered")


def main():
    port = int(os.environ.get("PORT", "9000"))
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
