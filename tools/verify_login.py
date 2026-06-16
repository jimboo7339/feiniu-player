#!/usr/bin/env python3
"""Quick login probe against Feiniu media server."""
import hashlib
import json
import os
import random
import sys
import time

try:
    import requests
except ImportError:
    import subprocess

    subprocess.check_call([sys.executable, "-m", "pip", "install", "requests", "-q"])
    import requests

API_KEY = "NDzZTVxnRKP8Z0jXg1VAMonaG8akvh"
API_SECRET = "16CCEB3D-AB42-077D-36A1-F355324E4237"
BASE = os.environ.get("FNOS_HOST", "http://192.168.100.10:8005")
USER = os.environ.get("FNOS_USER", "home")
PASS = os.environ.get("FNOS_PASS", "")


def md5hex(s: str) -> str:
    return hashlib.md5(s.encode()).hexdigest()


def gen_authx(path: str, body: str | None = None) -> str:
    nonce = str(100000 + random.randint(0, 899999))
    ts = str(int(time.time() * 1000))
    data_md5 = md5hex(body if body is not None else "")
    sign_str = f"{API_KEY}_{path}_{nonce}_{ts}_{data_md5}_{API_SECRET}"
    return f"nonce={nonce}&timestamp={ts}&sign={md5hex(sign_str)}"


def main() -> None:
    if not PASS:
        print("Set FNOS_PASS environment variable")
        sys.exit(1)
    nonce = str(100000 + random.randint(0, 899999))
    body = {
        "app_name": "trimemedia-web",
        "username": USER,
        "password": PASS,
        "nonce": nonce,
    }
    path = "/v/api/v1/login"
    body_str = json.dumps(body, separators=(",", ":"))
    r = requests.post(
        BASE + path,
        headers={
            "Authx": gen_authx(path, body_str),
            "Content-Type": "application/json",
            "Cookie": "mode=relay",
        },
        data=body_str,
        timeout=15,
    )
    print("login", r.status_code, r.text[:500])
    if r.status_code != 200:
        sys.exit(1)
    token = r.json()["data"]["token"]
    for ep in (
        "/v/api/v1/sys/version",
        "/v/api/v1/mediadb/list",
        "/v/api/v1/play/list",
    ):
        headers = {
            "Authx": gen_authx(ep, None),
            "Cookie": "mode=relay",
            "Authorization": token,
        }
        rr = requests.get(BASE + ep, headers=headers, timeout=15)
        print(ep, rr.status_code, rr.text[:300])


if __name__ == "__main__":
    main()
