#!/usr/bin/env python3
import hashlib
import json
import os
import random
import sys
import time

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


def api_call(method, path, token="", body=None):
    body_str = json.dumps(body, separators=(",", ":")) if body is not None else None
    headers = {"Authx": gen_authx(path, body_str), "Cookie": "mode=relay"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = token
    return requests.request(
        method,
        BASE + path,
        headers=headers,
        data=body_str,
        timeout=20,
    )


def main():
    if not PASS:
        print("Set FNOS_PASS")
        sys.exit(1)
    login_body = {
        "app_name": "trimemedia-web",
        "username": USER,
        "password": PASS,
        "nonce": "123456",
    }
    path = "/v/api/v1/login"
    r = api_call("POST", path, body=login_body)
    token = r.json()["data"]["token"]
    pl = api_call("GET", "/v/api/v1/play/list", token).json()
    item = pl["data"][0]["guid"] if pl.get("data") else None
    if not item:
        mdb = api_call("GET", "/v/api/v1/mediadb/list", token).json()
        ancestor = mdb["data"][0]["guid"]
        items = api_call(
            "POST",
            "/v/api/v1/item/list",
            token,
            {
                "ancestor_guid": ancestor,
                "page": 1,
                "page_size": 5,
                "exclude_grouped_video": 1,
                "sort_type": "DESC",
                "sort_column": "release_date",
            },
        ).json()
        item = items["data"]["list"][0]["guid"]
    pi = api_call("POST", "/v/api/v1/play/info", token, {"item_guid": item}).json()
    if pi.get("code") != 0:
        print("play/info failed", pi)
        sys.exit(1)
    media = pi["data"]["media_guid"]
    stream_body = {
        "media_guid": media,
        "ip": md5hex(USER),
        "level": 1,
        "header": {"User-Agent": ["Mozilla/5.0"]},
        "nonce": "123456",
    }
    st = api_call("POST", "/v/api/v1/stream", token, stream_body).json()
    data = st.get("data", {})
    fs = data.get("file_stream", {})
    dl = data.get("direct_link_qualities") or []
    print("item", item)
    print("file", fs.get("file_name"), "| path", fs.get("path"))
    print("strm", str(fs.get("path", "")).lower().endswith(".strm"))
    print("direct_link count", len(dl))
    if dl:
        print("direct url prefix", dl[0].get("url", "")[:100])


if __name__ == "__main__":
    main()
