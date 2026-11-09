# Korea Watch 2026

미국 정치권의 한국 관련 동향을 기록하는 사이트입니다. 2026-11-10 [미국 중간선거 한국어 브리핑](https://us-elections-2026.github.io/)에서 독립했습니다.

- 사이트: https://woochangkang.github.io/korea-watch-2026/
- 페이지: 동향·인물(`index.qmd`) · 한미 조인트 팩트시트(`fact-sheet.qmd`) · 한국 기업 미국 공장 지도(`plants.qmd`)

## 자료와 갱신

| 자료 | 갱신 경로 | 주기 |
|---|---|---|
| `data/korea_watch.csv` 동향 DB | Mac Studio 주간 발행(`us_elections.github.io/scripts/publish_weekly.sh`)이 `_NIS` Korea Watch DB를 `scripts/sync_korea_watch.py`로 옮겨 이 저장소에 push | 매주 일요일 |
| `data/korea/` 공장·보도 | 클라우드 루틴(`prompts/korea_plants_weekly.md`) → `korea-weekly/pending` 브랜치 → PR → 사람 확인 후 병합 | 매주 월요일 09:00 KST |
| 선거 등급·시장가 | 빌드 때 `scripts/fetch_election_data.py`가 본 사이트 저장소에서 받음(커밋 안 함) | 매일 11:00 KST 재빌드 |
| 지역구 배정 | 로컬 `scripts/build_korea_plants.py`(경계 원본 `~/code/_geo_dl`, 재획정 주 목록 `~/code/redistricting-2026`) | 새 공장 추가 때 |

자료 규칙은 [`data/korea/README.md`](data/korea/README.md)에 있습니다.

## 로컬 빌드

```bash
python3 scripts/fetch_election_data.py
python3 scripts/check_korea_weekly.py
quarto render
```
