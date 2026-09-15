#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import socket
import sys
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent
ENV_PATH = ROOT / ".env"
ALERTMANAGER_PATH = ROOT / "alertmanager.generated.yml"
HEX64 = re.compile(r"^[0-9a-fA-F]{64,}$")


def load_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        raise RuntimeError("deploy/stack/.env is missing; run sh init.sh first")
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
            value = value[1:-1]
        values[key.strip()] = value
    return values


def require(errors: list[str], condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def valid_host(host: str) -> bool:
    lowered = host.strip().lower().rstrip(".")
    if not lowered or lowered in {"localhost", "example.org", "example.com", "api.example.org"}:
        return False
    if lowered.endswith((".example", ".invalid", ".local")):
        return False
    return "." in lowered and " " not in lowered


def valid_https_url(value: str, *, allow_netlify: bool = True) -> bool:
    parsed = urlparse(value)
    if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password:
        return False
    host = (parsed.hostname or "").lower()
    if host in {"localhost", "example.com", "example.org", "example.invalid"}:
        return False
    if host.endswith((".example", ".invalid", ".local")):
        return False
    if not allow_netlify and host.endswith(".netlify.app"):
        return False
    return True


def main() -> int:
    try:
        env = load_env(ENV_PATH)
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    errors: list[str] = []
    warnings: list[str] = []

    require(errors, env.get("CW_DEPLOYMENT_ENV") == "production", "CW_DEPLOYMENT_ENV must be production")
    host = env.get("CW_API_HOST", "")
    require(errors, valid_host(host), "CW_API_HOST must be a real DNS hostname")
    require(errors, valid_https_url(env.get("CW_ALLOWED_ORIGIN", "")), "CW_ALLOWED_ORIGIN must be a real https:// origin")
    require(errors, valid_https_url(env.get("CW_ALERT_WEBHOOK_URL", "")), "CW_ALERT_WEBHOOK_URL must be a real https:// receiver")
    require(errors, env.get("CW_BACKUP_AGE_RECIPIENT", "").startswith("age1"), "CW_BACKUP_AGE_RECIPIENT must be an age public recipient")
    require(errors, HEX64.fullmatch(env.get("CW_TOKEN_PEPPER", "")) is not None, "CW_TOKEN_PEPPER must contain at least 256 bits of hex entropy")
    require(errors, HEX64.fullmatch(env.get("CW_WORKSITES_TOKEN", "")) is not None, "CW_WORKSITES_TOKEN must contain at least 256 bits of hex entropy")
    require(errors, env.get("CW_TOKEN_PEPPER") != env.get("CW_WORKSITES_TOKEN"), "platform pepper and internal worksite token must be distinct")
    require(errors, bool(env.get("CW_INCIDENT_RESPONSE_CONTACT", "").strip()), "CW_INCIDENT_RESPONSE_CONTACT must identify the on-call owner")
    require(errors, bool(env.get("CW_PRIVACY_CONTACT", "").strip()), "CW_PRIVACY_CONTACT must identify the privacy owner")
    require(errors, bool(env.get("CW_BACKUP_OWNER", "").strip()), "CW_BACKUP_OWNER must identify the recovery owner")

    try:
        retention = int(env.get("CW_DATA_RETENTION_DAYS", ""))
    except ValueError:
        retention = 0
    require(errors, 1 <= retention <= 3650, "CW_DATA_RETENTION_DAYS must be between 1 and 3650")

    if not ALERTMANAGER_PATH.is_file():
        errors.append("alertmanager.generated.yml is missing; run python generate-alertmanager-config.py")
    else:
        mode = ALERTMANAGER_PATH.stat().st_mode & 0o777
        require(errors, mode & 0o077 == 0, "alertmanager.generated.yml must not be group/world-readable")

    if host.endswith(".netlify.app"):
        warnings.append("API host is a Netlify hostname; a dedicated API hostname is recommended")

    if errors:
        print(json.dumps({"ok": False, "errors": errors, "warnings": warnings}, indent=2), file=sys.stderr)
        return 1

    result = {
        "ok": True,
        "deployment_env": "production",
        "api_host": host,
        "allowed_origin": env["CW_ALLOWED_ORIGIN"],
        "alert_delivery": "configured",
        "offsite_backup_encryption": "configured",
        "retention_days": retention,
        "named_operational_owners": True,
        "warnings": warnings,
    }
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
