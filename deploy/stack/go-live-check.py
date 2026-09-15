#!/usr/bin/env python3
from __future__ import annotations

import argparse
import ipaddress
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
AGE_RECIPIENT = re.compile(r"^age1[0-9a-z]{50,}$")
HOST_LABEL = re.compile(r"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$")
PLACEHOLDER_HOSTS = {"localhost", "example.com", "example.org", "example.net", "example.invalid", "api.example.org"}


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


def reserved_host(host: str) -> bool:
    lowered = host.lower().rstrip(".")
    return lowered in PLACEHOLDER_HOSTS or lowered.endswith((".example", ".invalid", ".local", ".test"))


def valid_host(host: str) -> bool:
    lowered = host.strip().lower().rstrip(".")
    if not lowered or reserved_host(lowered):
        return False
    try:
        ipaddress.ip_address(lowered)
        return False
    except ValueError:
        pass
    labels = lowered.split(".")
    return len(labels) >= 2 and all(HOST_LABEL.fullmatch(label) for label in labels)


def url_host(value: str) -> str | None:
    parsed = urlparse(value)
    if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.password:
        return None
    host = (parsed.hostname or "").lower().rstrip(".")
    if not host or reserved_host(host):
        return None
    return host


def resolves(host: str) -> bool:
    try:
        return bool(socket.getaddrinfo(host, 443, type=socket.SOCK_STREAM))
    except socket.gaierror:
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Fail-closed CrisisWeave production go-live checks")
    parser.add_argument("--skip-dns", action="store_true", help="CI/config validation only; do not use for a real go-live")
    args = parser.parse_args()

    try:
        env = load_env(ENV_PATH)
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    errors: list[str] = []
    warnings: list[str] = []

    require(errors, env.get("CW_DEPLOYMENT_ENV") == "production", "CW_DEPLOYMENT_ENV must be production")
    api_host = env.get("CW_API_HOST", "").strip().lower().rstrip(".")
    allowed_origin_host = url_host(env.get("CW_ALLOWED_ORIGIN", ""))
    alert_host = url_host(env.get("CW_ALERT_WEBHOOK_URL", ""))
    require(errors, valid_host(api_host), "CW_API_HOST must be a real DNS hostname, not an IP or placeholder")
    require(errors, allowed_origin_host is not None, "CW_ALLOWED_ORIGIN must be a real https:// origin")
    require(errors, alert_host is not None, "CW_ALERT_WEBHOOK_URL must be a real https:// receiver")
    require(errors, env.get("CW_ALERTMANAGER_CONFIG") == "./alertmanager.generated.yml", "CW_ALERTMANAGER_CONFIG must select ./alertmanager.generated.yml in production")
    require(errors, AGE_RECIPIENT.fullmatch(env.get("CW_BACKUP_AGE_RECIPIENT", "")) is not None, "CW_BACKUP_AGE_RECIPIENT must be a valid age1 public recipient")
    require(errors, HEX64.fullmatch(env.get("CW_TOKEN_PEPPER", "")) is not None, "CW_TOKEN_PEPPER must contain at least 256 bits of hex entropy")
    require(errors, HEX64.fullmatch(env.get("CW_WORKSITES_TOKEN", "")) is not None, "CW_WORKSITES_TOKEN must contain at least 256 bits of hex entropy")
    require(errors, env.get("CW_TOKEN_PEPPER") != env.get("CW_WORKSITES_TOKEN"), "platform pepper and internal worksite token must be distinct")
    require(errors, bool(env.get("CW_INCIDENT_RESPONSE_CONTACT", "").strip()), "CW_INCIDENT_RESPONSE_CONTACT must identify the on-call owner")
    require(errors, bool(env.get("CW_PRIVACY_CONTACT", "").strip()), "CW_PRIVACY_CONTACT must identify the privacy owner")
    require(errors, bool(env.get("CW_BACKUP_OWNER", "").strip()), "CW_BACKUP_OWNER must identify the recovery owner")

    try:
        retention = int(env.get("CW_DATA_RETENTION_DAYS", ""))
        credential_retention = int(env.get("CW_TOKEN_RETENTION_DAYS", ""))
    except ValueError:
        retention = credential_retention = 0
    require(errors, 1 <= retention <= 3650, "CW_DATA_RETENTION_DAYS must be between 1 and 3650")
    require(errors, 1 <= credential_retention <= 3650, "CW_TOKEN_RETENTION_DAYS must be between 1 and 3650")

    if not ALERTMANAGER_PATH.is_file():
        errors.append("alertmanager.generated.yml is missing; run python3 generate-alertmanager-config.py")
    else:
        mode = ALERTMANAGER_PATH.stat().st_mode & 0o777
        require(errors, mode & 0o077 == 0, "alertmanager.generated.yml must not be group/world-readable")

    if not args.skip_dns:
        if valid_host(api_host):
            require(errors, resolves(api_host), f"CW_API_HOST does not resolve in DNS: {api_host}")
        if allowed_origin_host:
            require(errors, resolves(allowed_origin_host), f"CW_ALLOWED_ORIGIN hostname does not resolve in DNS: {allowed_origin_host}")
        if alert_host:
            require(errors, resolves(alert_host), f"CW_ALERT_WEBHOOK_URL hostname does not resolve in DNS: {alert_host}")
    else:
        warnings.append("DNS resolution checks were skipped; this mode is for CI/config validation only")

    if env.get("CW_ALLOWED_ORIGIN", "").endswith(".netlify.app"):
        warnings.append("browser origin still uses the Netlify default hostname; a controlled custom domain is recommended")

    if errors:
        print(json.dumps({"ok": False, "errors": errors, "warnings": warnings}, indent=2), file=sys.stderr)
        return 1

    result = {
        "ok": True,
        "deployment_env": "production",
        "api_host": api_host,
        "allowed_origin": env["CW_ALLOWED_ORIGIN"],
        "alert_delivery": "configured",
        "offsite_backup_encryption": "configured",
        "private_retention_days": retention,
        "credential_retention_days": credential_retention,
        "named_operational_owners": True,
        "dns_checked": not args.skip_dns,
        "warnings": warnings,
    }
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
