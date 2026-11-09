# CLAUDE.md — Korea Watch 2026

Claude Code가 이 저장소에서 작업할 때 따르는 지침이다. 사람용 개요는 README.md, 자료 규칙은 data/korea/README.md.

## 구조
- Quarto + R(gt) 정적 사이트, GitHub Actions(`publish.yml`)가 렌더해 Pages로 배포. 공개 저장소 `woochangkang/korea-watch-2026`.
- `R/helpers.R` — us-elections-2026.github.io에서 옮겨 온 Korea Watch 헬퍼(동향 표 `gt_korea_watch`, 팩트시트 `korea_jfs_*`, 공장 지도 `korea_plants_*`).
- 선거 자료(`data/house_cook_districts.json` 등 5개)는 본 사이트가 정본이다. `scripts/fetch_election_data.py`로 받아 쓰고 커밋하지 않는다(.gitignore). 로컬 렌더 전에 반드시 실행.

## 갱신 경로 (세 갈래 — 서로의 파일을 건드리지 않는다)
1. 동향 DB `data/korea_watch.csv` — Mac Studio 일요일 주간 발행이 push. 스키마 고정(열 추가·변경 금지).
2. 공장 `data/korea/` — 월요일 클라우드 루틴 trig_01PxbmNPJMZBgQVHSMDwXhkZ → `korea-weekly/pending` → PR. 새 공장은 `candidates/`에만 오므로 병합 전 로컬에서 `us_plants.csv`로 옮기고 `python3.11 scripts/build_korea_plants.py`로 지역구 배정.
3. 선거 자료 — 매일 빌드 때 자동.

## 원칙
- 숫자는 연 출처에 있는 것만. 기사를 열어 확인한 변경만 반영(검색 요약은 `pending_checks.csv`).
- 커밋 전 `python3 scripts/check_korea_weekly.py` 통과 + `quarto render` 성공 확인. 산문은 습니다체.
- Dropbox 충돌 사본은 .gitignore·_quarto.yml에서 제외된다. 두 대의 Mac이 같은 작업 사본을 공유하므로 push는 한 곳에서.
