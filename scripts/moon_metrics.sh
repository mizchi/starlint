#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/moon_metrics.sh init-db [--db <path>]
  scripts/moon_metrics.sh collect [options]
  scripts/moon_metrics.sh extract-bench
  scripts/moon_metrics.sh extract-coverage-files <coveralls-json>
  scripts/moon_metrics.sh extract-coverage-lines <coveralls-json>

Commands:
  init-db                  Create tables/views for metrics analysis.
  collect                  Run moon bench/coverage and store metrics into SQLite.
  extract-bench            Read moon benchmark raw output from stdin and emit NDJSON.
  extract-coverage-files   Read Coveralls JSON and emit per-file NDJSON.
  extract-coverage-lines   Read Coveralls JSON and emit per-line NDJSON.

Options for collect:
  --db <path>                SQLite file path (default: .metrics/moon_metrics.sqlite)
  --run-id <id>              Run identifier (default: UTC timestamp + git short SHA)
  --bench-package <pkg>      Bench package for moon bench (default: benchmarks)
  --coverage-package <pkg>   Package for moon coverage analyze (default: moon.mod.json name)
  --module-dir <dir>         Module root directory (default: .)
  --with-line-coverage       Store per-line coverage into coverage_line_metrics table
  -h, --help                 Show this help
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

sql_escape() {
  printf "%s" "$1" | sed "s/'/''/g"
}

require_tools() {
  local tool
  for tool in jq sqlite3 moon git awk sed head wc date find; do
    command -v "$tool" >/dev/null 2>&1 || die "required tool is missing: $tool"
  done
}

resolve_module_name() {
  if [[ -f "moon.mod.json" ]]; then
    jq -r '.name // ""' "moon.mod.json"
  else
    printf ""
  fi
}

resolve_run_id() {
  local now
  local short_sha
  now="$(date -u +%Y%m%dT%H%M%SZ)"
  short_sha="$(git rev-parse --short HEAD 2>/dev/null || echo "nogit")"
  printf "%s-%s" "$now" "$short_sha"
}

init_db() {
  local db_path="$1"
  sqlite3 "$db_path" <<'SQL'
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS runs (
  run_id TEXT PRIMARY KEY,
  collected_at TEXT NOT NULL,
  git_sha TEXT NOT NULL,
  moon_version TEXT NOT NULL,
  module_name TEXT NOT NULL,
  target_hint TEXT NOT NULL,
  bench_package TEXT NOT NULL,
  coverage_package TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS bench_metrics (
  run_id TEXT NOT NULL,
  package TEXT NOT NULL,
  filename TEXT NOT NULL,
  bench_name TEXT NOT NULL,
  mean_us REAL NOT NULL,
  min_us REAL NOT NULL,
  max_us REAL NOT NULL,
  std_dev_us REAL NOT NULL,
  std_dev_pct REAL NOT NULL,
  median_us REAL NOT NULL,
  iqr_us REAL NOT NULL,
  runs INTEGER NOT NULL,
  batch_size INTEGER NOT NULL,
  PRIMARY KEY (run_id, package, filename, bench_name),
  FOREIGN KEY (run_id) REFERENCES runs(run_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS coverage_file_metrics (
  run_id TEXT NOT NULL,
  filename TEXT NOT NULL,
  covered_points INTEGER NOT NULL,
  total_points INTEGER NOT NULL,
  line_rate REAL NOT NULL,
  PRIMARY KEY (run_id, filename),
  FOREIGN KEY (run_id) REFERENCES runs(run_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS coverage_line_metrics (
  run_id TEXT NOT NULL,
  filename TEXT NOT NULL,
  line_no INTEGER NOT NULL,
  hits INTEGER NOT NULL,
  PRIMARY KEY (run_id, filename, line_no),
  FOREIGN KEY (run_id) REFERENCES runs(run_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_bench_metrics_name_run
  ON bench_metrics(bench_name, run_id);
CREATE INDEX IF NOT EXISTS idx_coverage_file_rate_run
  ON coverage_file_metrics(line_rate, run_id);

CREATE VIEW IF NOT EXISTS run_metrics_summary AS
WITH bench AS (
  SELECT
    run_id,
    COUNT(*) AS bench_points,
    AVG(mean_us) AS bench_mean_us_avg,
    MAX(mean_us) AS bench_mean_us_max
  FROM bench_metrics
  GROUP BY run_id
),
cov AS (
  SELECT
    run_id,
    COUNT(*) AS coverage_files,
    SUM(covered_points) AS covered_points,
    SUM(total_points) AS total_points,
    CASE
      WHEN SUM(total_points) = 0 THEN 0
      ELSE 1.0 * SUM(covered_points) / SUM(total_points)
    END AS coverage_rate
  FROM coverage_file_metrics
  GROUP BY run_id
)
SELECT
  r.run_id,
  r.collected_at,
  r.git_sha,
  r.moon_version,
  r.module_name,
  r.target_hint,
  r.bench_package,
  r.coverage_package,
  COALESCE(bench.bench_points, 0) AS bench_points,
  bench.bench_mean_us_avg,
  bench.bench_mean_us_max,
  COALESCE(cov.coverage_files, 0) AS coverage_files,
  COALESCE(cov.covered_points, 0) AS covered_points,
  COALESCE(cov.total_points, 0) AS total_points,
  COALESCE(cov.coverage_rate, 0) AS coverage_rate
FROM runs AS r
LEFT JOIN bench ON bench.run_id = r.run_id
LEFT JOIN cov ON cov.run_id = r.run_id;

CREATE VIEW IF NOT EXISTS bench_timeseries AS
WITH base AS (
  SELECT
    m.run_id,
    r.collected_at,
    m.package,
    m.filename,
    m.bench_name,
    m.mean_us,
    m.min_us,
    m.max_us,
    m.std_dev_us,
    m.std_dev_pct,
    m.median_us,
    m.iqr_us,
    m.runs,
    m.batch_size,
    LAG(m.mean_us) OVER (
      PARTITION BY m.package, m.filename, m.bench_name
      ORDER BY r.collected_at, m.run_id
    ) AS prev_mean_us
  FROM bench_metrics AS m
  JOIN runs AS r ON r.run_id = m.run_id
)
SELECT
  run_id,
  collected_at,
  package,
  filename,
  bench_name,
  mean_us,
  min_us,
  max_us,
  std_dev_us,
  std_dev_pct,
  median_us,
  iqr_us,
  runs,
  batch_size,
  prev_mean_us,
  CASE
    WHEN prev_mean_us IS NULL THEN NULL
    ELSE mean_us - prev_mean_us
  END AS delta_us,
  CASE
    WHEN prev_mean_us IS NULL OR prev_mean_us = 0 THEN NULL
    ELSE (mean_us - prev_mean_us) / prev_mean_us
  END AS delta_ratio
FROM base;

CREATE VIEW IF NOT EXISTS bench_regressions_5pct AS
SELECT
  run_id,
  collected_at,
  package,
  filename,
  bench_name,
  mean_us,
  prev_mean_us,
  delta_us,
  delta_ratio
FROM bench_timeseries
WHERE prev_mean_us IS NOT NULL
  AND delta_ratio >= 0.05;

CREATE VIEW IF NOT EXISTS coverage_file_timeseries AS
WITH base AS (
  SELECT
    c.run_id,
    r.collected_at,
    c.filename,
    c.covered_points,
    c.total_points,
    c.line_rate,
    LAG(c.line_rate) OVER (
      PARTITION BY c.filename
      ORDER BY r.collected_at, c.run_id
    ) AS prev_line_rate
  FROM coverage_file_metrics AS c
  JOIN runs AS r ON r.run_id = c.run_id
)
SELECT
  run_id,
  collected_at,
  filename,
  covered_points,
  total_points,
  line_rate,
  prev_line_rate,
  CASE
    WHEN prev_line_rate IS NULL THEN NULL
    ELSE line_rate - prev_line_rate
  END AS delta_line_rate
FROM base;

CREATE VIEW IF NOT EXISTS coverage_drops_1pct AS
SELECT
  run_id,
  collected_at,
  filename,
  line_rate,
  prev_line_rate,
  delta_line_rate
FROM coverage_file_timeseries
WHERE prev_line_rate IS NOT NULL
  AND delta_line_rate <= -0.01;
SQL
}

init_db_command() {
  local db_path=".metrics/moon_metrics.sqlite"
  while (($# > 0)); do
    case "$1" in
      --db)
        [[ $# -ge 2 ]] || die "--db requires a value"
        db_path="$2"
        shift 2
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "unknown option for init-db: $1"
        ;;
    esac
  done
  mkdir -p "$(dirname "$db_path")"
  init_db "$db_path"
  echo "initialized db: $db_path"
}

extract_bench_ndjson() {
  awk '
    /----- BEGIN MOON TEST RESULT -----/ { in_block = 1; next }
    /----- END MOON TEST RESULT -----/   { in_block = 0; next }
    in_block { print }
  ' | jq -cr '
    select(.message | startswith("@BATCH_BENCH ")) as $result
    | ($result.message | sub("^@BATCH_BENCH "; "") | fromjson).summaries[]
    | {
        package: $result.package,
        filename: $result.filename,
        bench_name: (.name // "<unnamed>"),
        mean_us: .mean,
        min_us: .min,
        max_us: .max,
        std_dev_us: .std_dev,
        std_dev_pct: .std_dev_pct,
        median_us: .median,
        iqr_us: .iqr,
        runs: .runs,
        batch_size: .batch_size
      }
  '
}

extract_coverage_files_ndjson() {
  local coveralls_json="$1"
  jq -cr '
    .source_files[]
    | {
        filename: .name,
        total_points: (.coverage | map(select(. != null)) | length),
        covered_points: (.coverage | map(select(. != null and . > 0)) | length)
      }
    | .line_rate = (
        if .total_points == 0
        then 0
        else (.covered_points / .total_points)
        end
      )
  ' "$coveralls_json"
}

extract_coverage_lines_ndjson() {
  local coveralls_json="$1"
  jq -cr '
    .source_files[] as $file
    | $file.coverage
    | to_entries[]
    | select(.value != null)
    | {
        filename: $file.name,
        line_no: (.key + 1),
        hits: .value
      }
  ' "$coveralls_json"
}

collect_metrics() {
  local db_path=".metrics/moon_metrics.sqlite"
  local run_id=""
  local bench_package="benchmarks"
  local coverage_package=""
  local module_dir="."
  local with_line_coverage=0

  while (($# > 0)); do
    case "$1" in
      --db)
        [[ $# -ge 2 ]] || die "--db requires a value"
        db_path="$2"
        shift 2
        ;;
      --run-id)
        [[ $# -ge 2 ]] || die "--run-id requires a value"
        run_id="$2"
        shift 2
        ;;
      --bench-package)
        [[ $# -ge 2 ]] || die "--bench-package requires a value"
        bench_package="$2"
        shift 2
        ;;
      --coverage-package)
        [[ $# -ge 2 ]] || die "--coverage-package requires a value"
        coverage_package="$2"
        shift 2
        ;;
      --module-dir)
        [[ $# -ge 2 ]] || die "--module-dir requires a value"
        module_dir="$2"
        shift 2
        ;;
      --with-line-coverage)
        with_line_coverage=1
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
  done

  require_tools
  cd "$module_dir"

  if [[ -z "$coverage_package" ]]; then
    coverage_package="$(resolve_module_name)"
  fi
  [[ -n "$coverage_package" ]] || die "coverage package is empty; set --coverage-package"

  if [[ -z "$run_id" ]]; then
    run_id="$(resolve_run_id)"
  fi

  mkdir -p "$(dirname "$db_path")"
  mkdir -p ".metrics/tmp/$run_id"
  init_db "$db_path"

  local tmp_root=".metrics/tmp/$run_id"
  local bench_raw_path="$tmp_root/bench.raw.log"
  local bench_ndjson_path="$tmp_root/bench.ndjson"
  local bench_json_path="$tmp_root/bench.json"
  local coverage_json_path="$tmp_root/coverage.coveralls.json"
  local coverage_files_ndjson_path="$tmp_root/coverage_files.ndjson"
  local coverage_files_json_path="$tmp_root/coverage_files.json"
  local coverage_lines_ndjson_path="$tmp_root/coverage_lines.ndjson"
  local coverage_lines_json_path="$tmp_root/coverage_lines.json"

  moon bench -p "$bench_package" --build-only >/dev/null

  local bench_pkg_dir_name="${bench_package##*/}"
  local bench_driver_path
  bench_driver_path="$(find "_build" -type f -path "*/bench/*" -name "${bench_pkg_dir_name}.whitebox_test.exe" | head -n 1)"
  [[ -n "$bench_driver_path" ]] || die "bench driver not found for package: $bench_package"

  local bench_info_path
  bench_info_path="$(dirname "$bench_driver_path")/__whitebox_test_info.json"
  [[ -f "$bench_info_path" ]] || die "bench info json not found: $bench_info_path"

  local bench_arg
  bench_arg="$(jq -r '
    .with_bench_args_tests
    | to_entries
    | map(.key as $f | .value[] | "\($f):\(.index)-\(.index + 1)")
    | join("/")
  ' "$bench_info_path")"

  if [[ -n "$bench_arg" ]]; then
    "$bench_driver_path" "$bench_arg" >"$bench_raw_path"
  else
    : >"$bench_raw_path"
  fi

  extract_bench_ndjson <"$bench_raw_path" >"$bench_ndjson_path"
  jq -s '.' "$bench_ndjson_path" >"$bench_json_path"

  moon coverage analyze -p "$coverage_package" -- -f coveralls -o "$coverage_json_path" >/dev/null
  extract_coverage_files_ndjson "$coverage_json_path" >"$coverage_files_ndjson_path"
  jq -s '.' "$coverage_files_ndjson_path" >"$coverage_files_json_path"

  if [[ "$with_line_coverage" -eq 1 ]]; then
    extract_coverage_lines_ndjson "$coverage_json_path" >"$coverage_lines_ndjson_path"
    jq -s '.' "$coverage_lines_ndjson_path" >"$coverage_lines_json_path"
  else
    printf '[]' >"$coverage_lines_json_path"
  fi

  local collected_at
  local git_sha
  local moon_version
  local module_name
  local target_hint
  collected_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  git_sha="$(git rev-parse HEAD 2>/dev/null || echo "")"
  moon_version="$(moon version | head -n 1)"
  module_name="$(resolve_module_name)"
  target_hint="$(echo "$bench_driver_path" | sed -E 's#^_build/([^/]+)/([^/]+)/bench/.*#\1/\2#')"

  local sq_db_run_id
  local sq_collected_at
  local sq_git_sha
  local sq_moon_version
  local sq_module_name
  local sq_target_hint
  local sq_bench_package
  local sq_coverage_package
  local sq_bench_json_path
  local sq_coverage_files_json_path
  local sq_coverage_lines_json_path

  sq_db_run_id="$(sql_escape "$run_id")"
  sq_collected_at="$(sql_escape "$collected_at")"
  sq_git_sha="$(sql_escape "$git_sha")"
  sq_moon_version="$(sql_escape "$moon_version")"
  sq_module_name="$(sql_escape "$module_name")"
  sq_target_hint="$(sql_escape "$target_hint")"
  sq_bench_package="$(sql_escape "$bench_package")"
  sq_coverage_package="$(sql_escape "$coverage_package")"
  sq_bench_json_path="$(sql_escape "$bench_json_path")"
  sq_coverage_files_json_path="$(sql_escape "$coverage_files_json_path")"
  sq_coverage_lines_json_path="$(sql_escape "$coverage_lines_json_path")"

  sqlite3 "$db_path" <<SQL
PRAGMA foreign_keys = ON;
BEGIN;

INSERT OR REPLACE INTO runs (
  run_id, collected_at, git_sha, moon_version, module_name, target_hint, bench_package, coverage_package
) VALUES (
  '$sq_db_run_id',
  '$sq_collected_at',
  '$sq_git_sha',
  '$sq_moon_version',
  '$sq_module_name',
  '$sq_target_hint',
  '$sq_bench_package',
  '$sq_coverage_package'
);

WITH rows AS (
  SELECT value AS row
  FROM json_each(readfile('$sq_bench_json_path'))
)
INSERT OR REPLACE INTO bench_metrics (
  run_id, package, filename, bench_name,
  mean_us, min_us, max_us, std_dev_us, std_dev_pct, median_us, iqr_us,
  runs, batch_size
)
SELECT
  '$sq_db_run_id',
  json_extract(row, '$.package'),
  json_extract(row, '$.filename'),
  json_extract(row, '$.bench_name'),
  CAST(json_extract(row, '$.mean_us') AS REAL),
  CAST(json_extract(row, '$.min_us') AS REAL),
  CAST(json_extract(row, '$.max_us') AS REAL),
  CAST(json_extract(row, '$.std_dev_us') AS REAL),
  CAST(json_extract(row, '$.std_dev_pct') AS REAL),
  CAST(json_extract(row, '$.median_us') AS REAL),
  CAST(json_extract(row, '$.iqr_us') AS REAL),
  CAST(json_extract(row, '$.runs') AS INTEGER),
  CAST(json_extract(row, '$.batch_size') AS INTEGER)
FROM rows;

WITH rows AS (
  SELECT value AS row
  FROM json_each(readfile('$sq_coverage_files_json_path'))
)
INSERT OR REPLACE INTO coverage_file_metrics (
  run_id, filename, covered_points, total_points, line_rate
)
SELECT
  '$sq_db_run_id',
  json_extract(row, '$.filename'),
  CAST(json_extract(row, '$.covered_points') AS INTEGER),
  CAST(json_extract(row, '$.total_points') AS INTEGER),
  CAST(json_extract(row, '$.line_rate') AS REAL)
FROM rows;

WITH rows AS (
  SELECT value AS row
  FROM json_each(readfile('$sq_coverage_lines_json_path'))
)
INSERT OR REPLACE INTO coverage_line_metrics (
  run_id, filename, line_no, hits
)
SELECT
  '$sq_db_run_id',
  json_extract(row, '$.filename'),
  CAST(json_extract(row, '$.line_no') AS INTEGER),
  CAST(json_extract(row, '$.hits') AS INTEGER)
FROM rows;

COMMIT;
SQL

  local bench_count
  local coverage_file_count
  bench_count="$(wc -l <"$bench_ndjson_path" | tr -d ' ')"
  coverage_file_count="$(wc -l <"$coverage_files_ndjson_path" | tr -d ' ')"

  echo "saved metrics:"
  echo "  run_id: $run_id"
  echo "  db: $db_path"
  echo "  bench points: $bench_count"
  echo "  coverage files: $coverage_file_count"
  if [[ "$with_line_coverage" -eq 1 ]]; then
    echo "  coverage lines: $(wc -l <"$coverage_lines_ndjson_path" | tr -d ' ')"
  fi
}

main() {
  local cmd="${1:-collect}"
  case "$cmd" in
    init-db)
      shift
      init_db_command "$@"
      ;;
    collect)
      shift
      collect_metrics "$@"
      ;;
    extract-bench)
      shift
      (($# == 0)) || die "extract-bench takes no arguments"
      extract_bench_ndjson
      ;;
    extract-coverage-files)
      shift
      (($# == 1)) || die "extract-coverage-files requires <coveralls-json>"
      extract_coverage_files_ndjson "$1"
      ;;
    extract-coverage-lines)
      shift
      (($# == 1)) || die "extract-coverage-lines requires <coveralls-json>"
      extract_coverage_lines_ndjson "$1"
      ;;
    -h | --help | help)
      usage
      ;;
    *)
      die "unknown command: $cmd"
      ;;
  esac
}

main "$@"
