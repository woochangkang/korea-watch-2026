#!/usr/bin/env python3
"""Korea Watch 데이터 검사(주간 점검 루틴·배포 빌드 공용)(표준 라이브러리만 — 클라우드에 R이 없어도 돈다).

scripts/validate_data.R 의 korea 검사와 같은 규칙. 위반이 있으면 종료코드 1.
"""
import csv, json, re, sys
from pathlib import Path

K = Path(__file__).resolve().parent.parent / "data" / "korea"
errs = []
rows = lambda f: list(csv.DictReader((K / f).open(encoding="utf-8")))

plants = rows("us_plants.csv")
ids = [p["id"] for p in plants]
dist = {d["id"] for d in json.loads((K / "us_plants_districts.json").read_text())["plants"]}
if len(ids) != len(set(ids)):
    errs.append("us_plants.csv id 중복")
if set(ids) != dist:
    errs.append(f"us_plants.csv와 us_plants_districts.json id 불일치: {sorted(set(ids) ^ dist)} "
                "— 새 공장은 candidates/에만 넣는다")
DATE = re.compile(r"^\d{4}(-\d{2}(-\d{2})?)?$")
for p in plants:
    if p["status"] not in {"operating", "under_construction", "announced", "paused", "closed"}:
        errs.append(f"{p['id']} status 허용값 밖: {p['status']}")
    if p["verified"] not in {"fetched", "partial"}:
        errs.append(f"{p['id']} verified 허용값 밖")
    if not p["source_url"].startswith(("http://", "https://")):
        errs.append(f"{p['id']} source_url")
    if p.get("latest_news") and not DATE.match(p["latest_news"]):
        errs.append(f"{p['id']} latest_news 형식: {p['latest_news']}")
    if p.get("latest_news_url") and not p["latest_news_url"].startswith(("http://", "https://")):
        errs.append(f"{p['id']} latest_news_url")

EVENTS = {"announce", "groundbreaking", "construction", "start", "expansion", "pause",
          "closure", "sale", "incident", "policy", "other"}
for i, n in enumerate(rows("plant_news.csv"), 2):
    if n["plant_id"] not in set(ids):
        errs.append(f"plant_news.csv {i}행 plant_id 없음: {n['plant_id']}")
    if not DATE.match(n["date"]):
        errs.append(f"plant_news.csv {i}행 date 형식: {n['date']}")
    if n["event"] not in EVENTS:
        errs.append(f"plant_news.csv {i}행 event: {n['event']}")
    if not n["url"].startswith(("http://", "https://")):
        errs.append(f"plant_news.csv {i}행 url")
    if n["fetched"] not in {"Y", "N"}:
        errs.append(f"plant_news.csv {i}행 fetched")

rows("pending_checks.csv")  # 파싱만
for f in sorted((K / "candidates").glob("*.csv")) if (K / "candidates").exists() else []:
    for c in csv.DictReader(f.open(encoding="utf-8")):
        if not c.get("source_url", "").startswith(("http://", "https://")):
            errs.append(f"{f.name} {c.get('id')} source_url")

# 동향 DB — 스키마 고정(열 추가·변경 금지). 갱신은 Mac 주간 발행의 scripts/sync_korea_watch.py.
KW = K.parent / "korea_watch.csv"
kw = list(csv.DictReader(KW.open(encoding="utf-8")))
KW_COLS = ["date", "type", "actor", "affiliation", "state_or_district", "event", "detail",
           "race_link", "significance", "source_url"]
if list(kw[0].keys()) != KW_COLS:
    errs.append(f"korea_watch.csv 열이 스키마와 다름: {list(kw[0].keys())}")
for i, r in enumerate(kw, 2):
    if not DATE.match(r["date"]):
        errs.append(f"korea_watch.csv {i}행 date: {r['date']}")
    if r["significance"] not in {"1", "2", "3"}:
        errs.append(f"korea_watch.csv {i}행 significance: {r['significance']}")

if errs:
    print("✗ korea 데이터 검사 실패:", *errs, sep="\n  - ")
    sys.exit(1)
print(f"✓ korea 데이터 검사 통과 — 공장 {len(plants)}곳, 동향 DB {len(kw)}행")
