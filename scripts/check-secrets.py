#!/usr/bin/env python3
from __future__ import annotations
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SELF = Path(__file__).resolve()
FORBIDDEN_NAMES = {".env", "id_rsa", "id_ed25519", "credentials.json", "secrets.json"}
SKIP_DIRS = {".git", "__pycache__", "node_modules"}
SENSITIVE_WORDS = ("api_key", "apikey", "token", "secret", "password", "private_key", "client_secret")
PLACEHOLDERS = ("REPLACE_", "EXAMPLE", "CHANGEME", "${", "<", "YOUR_")
TEXT_SUFFIXES = {"", ".md", ".txt", ".json", ".yml", ".yaml", ".toml", ".py", ".js", ".ts", ".html", ".css", ".sh", ".ps1", ".example"}
KEY_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_.-]*$")

def iter_files():
    for path in ROOT.rglob("*"):
        if path.is_file() and path.resolve() != SELF and not any(part in SKIP_DIRS for part in path.parts):
            yield path

def suspicious_assignment(line: str) -> bool:
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        return False
    separator = "=" if "=" in stripped else ":" if ":" in stripped else None
    if not separator:
        return False
    key, value = stripped.split(separator, 1)
    key = key.strip()
    value = value.strip().strip("'\"")
    if not KEY_RE.fullmatch(key):
        return False
    low_key = key.lower()
    if not any(word in low_key for word in SENSITIVE_WORDS):
        return False
    if not value or any(marker in value.upper() for marker in PLACEHOLDERS):
        return False
    if value.startswith(("http://", "https://", "/")):
        return False
    return len(value) >= 16

def main() -> int:
    failures = []
    private_key_marker = "-----BEGIN " + "PRIVATE KEY-----"
    for path in iter_files():
        rel = path.relative_to(ROOT)
        if path.name in FORBIDDEN_NAMES or (path.name.startswith(".env.") and path.name != ".env.example"):
            failures.append(f"forbidden secret-bearing filename: {rel}")
            continue
        if path.suffix.lower() not in TEXT_SUFFIXES and path.name != ".env.example":
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if private_key_marker in text:
            failures.append(f"private key material in {rel}")
        for number, line in enumerate(text.splitlines(), 1):
            if suspicious_assignment(line):
                failures.append(f"possible secret assignment in {rel}:{number}")
    if failures:
        print("Potential secrets detected:", file=sys.stderr)
        for item in failures:
            print(f"- {item}", file=sys.stderr)
        return 1
    print("Secret scan passed")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
