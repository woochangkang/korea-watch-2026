#!/usr/bin/env python3
"""본 사이트(us-elections-2026.github.io, 공개 저장소) main의 선거 자료를 data/로 받아 온다.

공장 지도의 지역구 선거 상황(Cook 하원·상원·주지사 등급, Kalshi 가격)은 여기서 읽는다.
값은 본 사이트가 정본이고 이 저장소는 복사본만 쓴다 — 커밋하지 않는다(.gitignore).
빌드(Actions)와 로컬 렌더 전에 매번 실행한다. 받지 못하면 실패로 끝낸다(낡은 값으로 렌더하지 않게).
"""
import json, sys, urllib.request
from pathlib import Path

BASE = "https://raw.githubusercontent.com/us-elections-2026/us-elections-2026.github.io/main/data/"
FILES = ["house_cook_districts.json", "house_races.json", "senate_ratings_feed.json",
         "governor_ratings.json", "kalshi_prices.json"]
OUT = Path(__file__).resolve().parent.parent / "data"

for f in FILES:
    with urllib.request.urlopen(BASE + f, timeout=30) as r:
        body = r.read()
    d = json.loads(body)  # 깨진 파일이면 여기서 실패
    (OUT / f).write_bytes(body)
    print(f"{f}: as_of {d.get('as_of') or d.get('fetched_at')}")
