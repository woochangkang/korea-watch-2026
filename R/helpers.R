# R/helpers.R
# Korea Watch 헬퍼 — 2026-11-10 us-elections-2026.github.io R/helpers.R에서 Korea Watch 부분만 옮겨 왔다.
# 선거 등급(house_cook_districts 등)은 scripts/fetch_election_data.py가 본 사이트 저장소에서 data/로 받아 온다.
# 핵심 원칙: 정규화(comparability) · 변화추적(delta) · 출처라벨(provenance)

suppressPackageStartupMessages({
  library(jsonlite)
  library(dplyr)
  library(gt)
  library(readr)
})

# _quarto.yml 에서 execute-dir: project 로 두어 작업 경로를 레포 루트로 고정한다.
.load_json <- function(name) {
  jsonlite::read_json(file.path("data", paste0(name, ".json")),
                      simplifyVector = TRUE)
}


.tbl_opts <- function(g) {
  g |>
    opt_table_font(font = list(gt::google_font("IBM Plex Sans KR"), gt::default_fonts())) |>
    tab_options(
      table.font.size = px(14),
      heading.title.font.size = px(16),
      heading.subtitle.font.size = px(12),
      column_labels.font.weight = "bold",
      data_row.padding = px(6),
      table.border.top.style = "none"
    )
}

# 2.2 Korea Watch 동향 표 ------------------------------------------------------
# data/korea_watch.csv — 누적 DB. 스키마 고정(열 추가·변경 금지):
# date,type,actor,affiliation,state_or_district,event,detail,race_link,significance,source_url
gt_korea_watch <- function(n = 30) {
  kw <- readr::read_csv(file.path("data", "korea_watch.csv"),
                        show_col_types = FALSE,
                        col_types = readr::cols(.default = readr::col_character(),
                                                significance = readr::col_integer()))
  if (nrow(kw) == 0) {
    return(tibble(안내 = "수집된 항목이 아직 없습니다 — Korea Watch 일일 수집 시작 후 이 표가 채워집니다.") |>
             gt() |> tab_header(title = "Korea Watch — 한국 관련 동향") |> .tbl_opts())
  }
  kw |>
    arrange(desc(date)) |>
    head(n) |>
    mutate(중요도 = strrep("★", significance)) |>
    transmute(
      날짜 = date, 유형 = type, 행위자 = actor,
      소속 = ifelse(is.na(affiliation), "—", affiliation),
      내용 = event,
      `선거 연관` = ifelse(is.na(race_link), "—", race_link),
      중요도,
      출처 = ifelse(is.na(source_url), "—",
                  paste0("<a href='", source_url, "'>링크</a>"))
    ) |>
    gt() |>
    fmt_markdown(columns = "출처") |>
    tab_header(title = "Korea Watch — 한국 관련 동향 (최신순)",
               subtitle = paste0("누적 ", nrow(kw), "건 중 최근 ", min(n, nrow(kw)), "건 표시")) |>
    .tbl_opts()
}


# 2.10 Korea Watch — 한미 조인트 팩트시트(2025-11-13/14) -------------------------
# data/korea/joint_fact_sheet.json — 원문 41개 문단(ko=대통령실 국문본, en=백악관 원문)을
# 사이트 편집 분류(sector·theme·label)로 묶은 것. 원문 문구는 고치지 않는다.
.jfs <- function() jsonlite::read_json(file.path("data", "korea", "joint_fact_sheet.json"),
                                       simplifyVector = FALSE)

korea_jfs_md <- function(sector = c("경제", "안보")) {
  sector <- match.arg(sector)
  d <- .jfs()
  kn <- Filter(function(k) k$sector == sector, d$key_numbers)
  tiles <- paste0('<div class="kpis">',
                  paste(vapply(kn, function(k) sprintf(
                    '<div class="kpi"><div class="kpi-num">%s</div><div class="kpi-lab">%s</div></div>',
                    k$value, k$label), character(1)), collapse = ""), "</div>\n")
  its <- Filter(function(i) i$sector == sector, d$items)
  blocks <- vapply(d$theme_order[[sector]], function(th) {
    x <- Filter(function(i) i$theme == th, its)
    if (!length(x)) return("")
    rows <- vapply(x, function(i) sprintf(
      "- **%s**\n  <details class=\"jfs-src\"><summary>원문 보기 · %s</summary><p>%s</p><p lang=\"en\">%s</p></details>",
      i$label, i$section_ko, i$ko, i$en), character(1))
    paste0("\n#### ", th, "\n\n", paste(rows, collapse = "\n"), "\n")
  }, character(1))
  paste0(tiles, paste(blocks, collapse = ""))
}

# 팩트시트 이후 이행 경과 — Korea Watch DB에서 '팩트시트'를 언급한 행을 최신순으로.
korea_jfs_followup_md <- function(n = 12) {
  kw <- readr::read_csv(file.path("data", "korea_watch.csv"), show_col_types = FALSE,
                        col_types = readr::cols(.default = readr::col_character()))
  hit <- grepl("팩트시트|fact sheet", paste(kw$event, kw$detail), ignore.case = TRUE)
  x <- kw[hit, ]
  x <- x[order(x$date, decreasing = TRUE), ][seq_len(min(n, sum(hit))), ]
  if (!nrow(x)) return('<p class="pt-empty">DB에 팩트시트를 언급한 항목이 아직 없습니다.</p>\n')
  rows <- sprintf("- **%s** · %s · %s ([출처](%s))", x$date, x$type, x$event, x$source_url)
  paste0(paste(rows, collapse = "\n"),
         sprintf('\n\n<p class="muted">위 동향 DB에서 \'팩트시트\'를 언급한 %d건을 자동으로 모았습니다. 원문 기록이라 다체가 섞입니다.</p>\n', sum(hit)))
}

# 2.11 Korea Watch — 한국 30대 그룹 미국 공장 × 2026 선거 -------------------------
# data/korea/us_plants.csv          공장 목록(행마다 출처 URL·검증 수준). 수기 정리본.
# data/korea/us_plants_districts.json  scripts/build_korea_plants.py 산출(좌표→2026 지역구).
# data/korea/plant_districts.geojson   공장이 있는 지역구 경계(단순화).
# 선거 상황은 렌더 때 사이트 데이터(Cook 하원·상원·주지사 등급, Kalshi)에서 읽는다 — 박지 않는다.
.KP_STATUS <- c(operating = "가동", under_construction = "건설 중", announced = "발표(미착공)",
                paused = "중단·보류", closed = "폐쇄·매각")
.KP_RATING_KEY <- c("Solid D" = "solid_d", "Likely D" = "likely_d", "Lean D" = "lean_d", "Leans D" = "lean_d",
                    "Toss-up" = "tossup", "Toss Up" = "tossup", "Lean R" = "lean_r", "Leans R" = "lean_r",
                    "Likely R" = "likely_r", "Solid R" = "solid_r")
.kp_cd <- function(x) sub("-0*", "-", x)   # "NC-01" → "NC-1"
# 인라인 <script type="application/json"> 안에서 HTML 파서가 조기 종료하지 않게("</script>")
.kp_json_safe <- function(x) {
  x <- gsub("<", "\\u003c", x, fixed = TRUE)
  x <- gsub("\u2028", "\\u2028", x, fixed = TRUE)
  gsub("\u2029", "\\u2029", x, fixed = TRUE)
}
.kp_esc <- function(x) ifelse(is.na(x), NA_character_, htmltools::htmlEscape(x))
.kp_url <- function(x) ifelse(!is.na(x) & grepl("^https?://", x), htmltools::htmlEscape(x, attribute = TRUE), NA_character_)

korea_plants_data <- function() {
  p <- readr::read_csv(file.path("data", "korea", "us_plants.csv"), show_col_types = FALSE,
                       col_types = readr::cols(.default = readr::col_character()))
  dj <- jsonlite::read_json(file.path("data", "korea", "us_plants_districts.json"), simplifyVector = TRUE)$plants
  p <- dplyr::left_join(p[, setdiff(names(p), c("lat", "lon"))],
                        dj[, c("id", "lat", "lon", "district", "district_map", "district_certain",
                               "census_cd120", "census_match")], by = "id")
  p$district_alt <- vapply(p$id, function(i) {
    x <- dj$district_candidates[[match(i, dj$id)]]
    if (length(x) > 1) paste(x, collapse = "·") else NA_character_
  }, character(1))
  hc <- .load_json("house_cook_districts")
  cd <- hc$districts
  p$house_rating <- cd$rating[match(p$district, cd$district)]
  p$house_party  <- cd$party[match(p$district, cd$district)]
  p$house_inc    <- cd$incumbent[match(p$district, cd$district)]
  hr <- .load_json("house_races")$races
  hr$cd <- .kp_cd(hr$district)
  p$house_note <- hr$note[match(p$district, hr$cd)]
  p$house_inc  <- ifelse(is.na(p$house_inc), hr$incumbent[match(p$district, hr$cd)], p$house_inc)
  sen <- .load_json("senate_ratings_feed")$sources
  gov <- .load_json("governor_ratings")$sources
  sc <- sen$ratings[sen$label == "Cook Political Report", ]
  gc <- gov$ratings[gov$label == "Cook Political Report", ]
  p$senate_rating <- vapply(p$state, function(s) if (s %in% names(sc)) sc[[s]][1] else NA_character_, character(1))
  p$gov_rating    <- vapply(p$state, function(s) if (s %in% names(gc)) gc[[s]][1] else NA_character_, character(1))
  kal <- .load_json("kalshi_prices")
  p$senate_kalshi <- vapply(p$state, function(s) if (!is.null(kal$senate[[s]])) kal$senate[[s]]$dem else NA_real_, numeric(1))
  p$gov_kalshi    <- vapply(p$state, function(s) if (!is.null(kal$governor[[s]])) kal$governor[[s]]$dem else NA_real_, numeric(1))
  attr(p, "as_of") <- list(house = hc$as_of, senate = sen$as_of[sen$label == "Cook Political Report"],
                           gov = gov$as_of[gov$label == "Cook Political Report"], kalshi = kal$as_of)
  p
}

.kp_competitive <- function(r) !is.na(r) & .KP_RATING_KEY[r] %in% c("lean_d", "tossup", "lean_r")
.kp_rating_lab <- function(r) ifelse(is.na(r), "선거 없음", r)

# 요약 문단 — 숫자는 데이터에서 센다.
korea_plants_summary_md <- function() {
  p <- korea_plants_data()
  live <- p[p$status != "closed", ]
  nd <- length(unique(na.omit(live$district)))
  comp <- unique(live$district[.kp_competitive(live$house_rating)])
  sen_c <- unique(live$state[.kp_competitive(live$senate_rating) | (!is.na(live$senate_rating) & live$senate_rating == "Toss-up")])
  gov_c <- unique(live$state[.kp_competitive(live$gov_rating)])
  a <- attr(p, "as_of")
  nclosed <- nrow(p) - nrow(live)
  paste0(
    "- 지도에는 ", nrow(p), "곳을 올렸습니다. 이 가운데 가동·건설·발표·중단 상태인 **", nrow(live), "곳**이 ",
    length(unique(live$state)), "개 주, ", nd, "개 하원 지역구에 있습니다",
    if (nclosed) paste0("(폐쇄·매각 ", nclosed, "곳은 지도와 전체 목록에는 싣고 선거 관련 집계에서는 뺐습니다)") else "", ".\n",
    "- 하원 등급으로 보면 공화 우세(Solid·Likely R) 지역구에 ", sum(.KP_RATING_KEY[live$house_rating] %in% c("solid_r", "likely_r"), na.rm = TRUE),
    "곳, 민주 우세(Solid·Likely D) 지역구에 ", sum(.KP_RATING_KEY[live$house_rating] %in% c("solid_d", "likely_d"), na.rm = TRUE), "곳이 있습니다.\n",
    "- 이 가운데 Cook 하원 등급이 경합(Lean·Toss-up)인 지역구는 ",
    if (length(comp)) paste0("**", paste(sort(comp), collapse = "·"), "**입니다.") else "없습니다. 공장 대부분이 한쪽 정당이 확실한 지역구에 있습니다.", "\n",
    "- 상원 경합(Cook Lean·Toss-up) 주: ", if (length(sen_c)) paste(sort(sen_c), collapse = "·") else "없음",
    " · 주지사 경합 주: ", if (length(gov_c)) paste(sort(gov_c), collapse = "·") else "없음", ".\n",
    "\n<p class=\"muted\">등급 기준일 — 하원 Cook ", a$house, " · 상원 Cook ", a$senate,
    " · 주지사 Cook ", a$gov, " · Kalshi ", a$kalshi, ". 페이지를 다시 빌드할 때마다 새 등급으로 바뀝니다.</p>\n")
}

# Leaflet 지도. 데이터는 페이지에 인라인 JSON으로 싣는다(별도 fetch 없음).
korea_plants_map_html <- function(base = "") {
  p <- korea_plants_data()
  geo <- paste(readLines(file.path("data", "korea", "plant_districts.geojson"), warn = FALSE), collapse = "")
  pts <- p[!is.na(p$lat), ]
  pts$status_kr <- .KP_STATUS[pts$status]
  pts$house_key <- unname(.KP_RATING_KEY[pts$house_rating])
  js <- jsonlite::toJSON(pts[, c("id", "group", "company", "facility", "product", "status", "status_kr",
                                 "city", "state", "lat", "lon", "district", "investment_usd_m", "jobs",
                                 "house_rating", "house_key", "house_party", "house_inc",
                                 "senate_rating", "gov_rating", "source_url", "latest_news", "latest_news_url")],
                         dataframe = "rows", na = "null", auto_unbox = TRUE)
  cdr <- .load_json("house_cook_districts")$districts
  rmap <- jsonlite::toJSON(setNames(as.list(cdr$key), cdr$district), auto_unbox = TRUE)
  paste0(
    '<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css" integrity="sha512-h9FcoyWjHcOcmEVkxOfTLnmZFWIH0iZhZT1H2TbOq55xssQGEJHEaIm+PgoUaZbRvQTNTluNOEfb1ZRy6D3BOw==" crossorigin="anonymous" referrerpolicy="no-referrer">\n',
    '<script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js" integrity="sha512-puJW3E/qXDqYp9IfhAI54BJEaWIfloJ7JWs7OeD5i6ruC9JZL1gERT1wjtwXFlh7CjE7ZJ+/vcRZRkIYIb6p4g==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>\n',
    '<div id="kp-map" class="kp-map"><p class="kp-nomap">지도를 불러오는 중입니다. 계속 이 문구가 보이면 지도 라이브러리(cdnjs)를 불러오지 못한 것이니 아래 표를 이용하세요.</p></div>\n',
    '<div class="kp-legend" id="kp-legend"></div>\n',
    '<script type="application/json" id="kp-data">', .kp_json_safe(js), '</script>\n',
    '<script type="application/json" id="kp-geo">', .kp_json_safe(geo), '</script>\n',
    '<script type="application/json" id="kp-rating">', .kp_json_safe(rmap), '</script>\n',
    '<script src="', base, 'assets/korea_plants_map.js"></script>\n')
}

# Census 대조 문장 — 생성물(us_plants_districts.json)의 census_match에서 센다.
.kp_census_note <- function(p) {
  n <- nrow(p); ok <- sum(p$census_match %in% TRUE); na <- sum(is.na(p$census_match))
  unc <- sum(!is.na(p$district_alt))
  paste0("지역구는 2026 본선 경계 기준(재획정 9개 주는 새 지도)입니다. 배정에 쓴 좌표를 Census 지오코더의 120대 의회 지역구와 대조해 ",
         n, "곳 중 ", ok, "곳이 일치했습니다", if (na) paste0("(", na, "곳은 대조 실패)") else "", ". ",
         if (unc) paste0("다만 ※ 표시 ", unc, "곳은 부지 좌표를 못 찾아 도시 중심으로 배정했고 반경 8km 안에 다른 지역구가 걸쳐, 실제 부지의 지역구는 확정이 아닙니다. ") else "",
         "시장가는 확률이 아니라 가격입니다.")
}

# 지역구별 표 — 공장이 있는 지역구 하나당 한 행, 경합도 높은 순.
gt_korea_plants_districts <- function() {
  p <- korea_plants_data()
  p <- p[p$status != "closed" & !is.na(p$district), ]
  ord <- c(tossup = 1, lean_d = 2, lean_r = 2, likely_d = 3, likely_r = 3, solid_d = 4, solid_r = 4)
  unc <- ifelse(is.na(p$district_alt), "", paste0(" <span class='muted'>※ 부지 좌표 미확보, 후보 ", p$district_alt, "</span>"))
  fac <- tapply(seq_len(nrow(p)), p$district, function(i)
    paste(sprintf("%s <span class='muted'>(%s)</span>%s", .kp_esc(p$facility[i]), .KP_STATUS[p$status[i]], unc[i]),
          collapse = "<br>"))
  dd <- p[!duplicated(p$district), ]
  dd$facs <- fac[dd$district]
  dd$o <- ord[.KP_RATING_KEY[dd$house_rating]]
  dd <- dd[order(dd$o, dd$state, dd$district), ]
  sen <- ifelse(is.na(dd$senate_rating), "—",
                paste0(dd$senate_rating, ifelse(is.na(dd$senate_kalshi), "", sprintf(" · 시장 D %d¢", round(dd$senate_kalshi)))))
  gv <- ifelse(is.na(dd$gov_rating), "—",
               paste0(dd$gov_rating, ifelse(is.na(dd$gov_kalshi), "", sprintf(" · 시장 D %d¢", round(dd$gov_kalshi)))))
  a <- attr(p, "as_of")
  tibble(
    지역구 = dd$district,
    `하원 등급(Cook)` = ifelse(is.na(dd$house_rating), "—", dd$house_rating),
    `현 의석` = paste0(ifelse(is.na(dd$house_inc), "", paste0(dd$house_inc, " ")),
                ifelse(is.na(dd$house_party), "", paste0("(", dd$house_party, ")"))),
    `한국 기업 시설` = dd$facs,
    `상원(Cook)` = sen,
    `주지사(Cook)` = gv,
    비고 = ifelse(is.na(dd$house_note), "", dd$house_note)
  ) |>
    gt() |>
    fmt_markdown(columns = c("한국 기업 시설")) |>
    cols_align("left") |>
    cols_width(지역구 ~ pct(8), `하원 등급(Cook)` ~ pct(10), `현 의석` ~ pct(12), `한국 기업 시설` ~ pct(32),
               `상원(Cook)` ~ pct(13), `주지사(Cook)` ~ pct(13), 비고 ~ pct(12)) |>
    tab_options(table.width = pct(100)) |>
    tab_header(title = "공장이 있는 하원 지역구와 2026 선거 상황",
               subtitle = paste0("경합도 높은 순 · 하원 Cook ", a$house, " · 상원 Cook ", a$senate,
                                 " · 주지사 Cook ", a$gov, " · 시장가는 Kalshi 민주 승리 계약(", a$kalshi, ")")) |>
    tab_source_note(.kp_census_note(korea_plants_data())) |>
    .tbl_opts()
}

# 전체 시설 목록 — 주별, 출처 포함.
gt_korea_plants <- function() {
  p <- korea_plants_data()
  p <- p[order(p$state, p$group), ]
  money <- ifelse(is.na(p$investment_usd_m), "—", sprintf("$%sM", format(as.numeric(p$investment_usd_m), big.mark = ",", trim = TRUE)))
  tibble(
    주 = p$state,
    그룹 = paste0(.kp_esc(p$group), ifelse(is.na(p$group_rank), "", paste0(" <span class='muted'>", .kp_esc(p$group_rank), "위</span>"))),
    시설 = paste0(.kp_esc(p$facility), "<br><span class='muted'>", .kp_esc(p$sector), " · ", .kp_esc(p$product), "</span>"),
    위치 = paste0(.kp_esc(p$city), ifelse(is.na(p$district), "", paste0(" · ", p$district)),
                ifelse(is.na(p$district_alt), "", paste0(" <span class='muted'>(후보 ", p$district_alt, ")</span>"))),
    상태 = paste0(.KP_STATUS[p$status], ifelse(is.na(p$status_as_of), "", paste0(" <span class='muted'>(", .kp_esc(p$status_as_of), ")</span>"))),
    투자 = money,
    고용 = ifelse(is.na(p$jobs), "—", p$jobs),
    출처 = paste0(ifelse(is.na(.kp_url(p$source_url)), "—", paste0("<a href=\"", .kp_url(p$source_url), "\">링크</a>")),
                ifelse(is.na(.kp_url(p$source_url_2)), "", paste0(" · <a href=\"", .kp_url(p$source_url_2), "\">2</a>"))),
    `최근 보도` = ifelse(is.na(p$latest_news), "—",
                     ifelse(is.na(.kp_url(p$latest_news_url)), .kp_esc(p$latest_news),
                            paste0("<a href=\"", .kp_url(p$latest_news_url), "\">", .kp_esc(p$latest_news), "</a>"))),
    검증 = c(fetched = "출처 확인", partial = "일부 확인")[p$verified]
  ) |>
    gt(groupname_col = "주") |>
    fmt_markdown(columns = c("그룹", "시설", "위치", "상태", "출처", "최근 보도")) |>
    cols_align("left") |>
    cols_width(그룹 ~ pct(11), 시설 ~ pct(27), 위치 ~ pct(14), 상태 ~ pct(12), 투자 ~ pct(8),
               고용 ~ pct(6), 출처 ~ pct(6), `최근 보도` ~ pct(9), 검증 ~ pct(7)) |>
    tab_options(table.width = pct(100)) |>
    tab_header(title = "한국 100대 그룹의 미국 공장 — 전체 목록",
               subtitle = "그룹 순위는 공정위 2026년 공시대상기업집단(4/29 발표) · 투자·고용은 발표치") |>
    tab_source_note("검증: '출처 확인'은 연 페이지에서 위치·상태·금액을 확인한 행, '일부 확인'은 일부 항목이 검색 요약에만 기댄 행입니다. 행별 검증 메모는 data/korea/us_plants.csv의 notes 열에 있습니다.") |>
    .tbl_opts()
}

# 공장별 보도 경과 — data/korea/plant_news.csv(공장 id·날짜·사건·요약·매체·URL·열람 여부).
# 최근 보도가 새로운 공장부터, 공장 안에서는 날짜순. 검색 요약으로만 확인한 보도는 표시를 단다.
.KP_EVENT <- c(announce = "발표", groundbreaking = "착공", construction = "건설", start = "가동",
               expansion = "증설", pause = "중단", closure = "폐쇄", sale = "매각·인수",
               incident = "사건", policy = "정책", other = "기타")
korea_plants_news_md <- function() {
  p <- korea_plants_data()
  n <- readr::read_csv(file.path("data", "korea", "plant_news.csv"), show_col_types = FALSE,
                       col_types = readr::cols(.default = readr::col_character()))
  p <- p[order(p$latest_news, decreasing = TRUE, na.last = TRUE), ]
  blocks <- vapply(seq_len(nrow(p)), function(i) {
    x <- n[n$plant_id == p$id[i], ]
    if (!nrow(x)) return("")
    x <- x[order(x$date), ]
    items <- sprintf("<li><b>%s</b> · %s · %s (%s)%s</li>",
                     .kp_esc(x$date), .KP_EVENT[x$event], .kp_esc(x$summary_kr),
                     ifelse(is.na(.kp_url(x$url)), .kp_esc(x$outlet),
                            paste0("<a href=\"", .kp_url(x$url), "\">", .kp_esc(x$outlet), "</a>")),
                     ifelse(x$fetched == "Y", "", " <span class='muted'>[검색 요약]</span>"))
    sprintf("<details class=\"kp-news\"><summary><b>%s</b> · %s <span class='muted'>%s · %s · 최근 보도 %s</span></summary><ul>%s</ul></details>",
            .kp_esc(p$group[i]), .kp_esc(p$facility[i]), .kp_esc(p$state[i]),
            ifelse(is.na(p$district[i]), "", p$district[i]), ifelse(is.na(p$latest_news[i]), "—", .kp_esc(p$latest_news[i])),
            paste(items, collapse = ""))
  }, character(1))
  paste0(sprintf('<p class="muted">공장 %d곳의 보도 %d건입니다. 최근 보도가 새로운 공장부터 정렬했습니다. 날짜가 연·월까지만 있는 것은 기사에서 일자를 확인하지 못한 경우입니다. [검색 요약]은 기사를 열지 못하고 검색 결과로만 확인한 보도입니다.</p>\n',
                 sum(nzchar(blocks)), nrow(n)),
         paste(blocks[nzchar(blocks)], collapse = "\n"), "\n")
}
