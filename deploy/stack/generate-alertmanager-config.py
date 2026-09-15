#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent
ENV_PATH = ROOT / ".env"
OUT_PATH = ROOT / "alertmanager.generated.yml"


def load_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        raise SystemExit("deploy/stack/.env is missing; run sh init.sh first")
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
            value = value[1:-1]
        values[key] = value
    return values


def validated_webhook(value: str) -> str:
    parsed = urlparse(value)
    if parsed.scheme != "https" or not parsed.netloc:
        raise SystemExit("CW_ALERT_WEBHOOK_URL must be an https:// URL")
    if parsed.username or parsed.password:
        raise SystemExit("CW_ALERT_WEBHOOK_URL must not contain URL userinfo credentials")
    if parsed.hostname in {"example.com", "example.org", "example.invalid", "localhost"}:
        raise SystemExit("CW_ALERT_WEBHOOK_URL must point to a real external alert receiver")
    return value


def main() -> int:
    env = load_env(ENV_PATH)
    webhook = validated_webhook(env.get("CW_ALERT_WEBHOOK_URL", "").strip())
    text = "\n".join(
        [
            "global:",
            "  resolve_timeout: 5m",
            "route:",
            "  receiver: crisisweave-ops",
            "  group_by: [alertname]",
            "  group_wait: 30s",
            "  group_interval: 5m",
            "  repeat_interval: 2h",
            "receivers:",
            "  - name: crisisweave-ops",
            "    webhook_configs:",
            f"      - url: {json.dumps(webhook)}",
            "        send_resolved: true",
            "",
        ]
    )
    tmp = OUT_PATH.with_suffix(".tmp")
    tmp.write_text(text, encoding="utf-8")
    os.chmod(tmp, 0o600)
    tmp.replace(OUT_PATH)
    os.chmod(OUT_PATH, 0o600)
    print(f"wrote {OUT_PATH.name} with mode 0600")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
