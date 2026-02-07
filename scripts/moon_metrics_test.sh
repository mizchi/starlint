#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOL="$SCRIPT_DIR/moon_metrics.sh"
FIXTURE_DIR="$SCRIPT_DIR/testdata"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

assert_eq() {
  local got="$1"
  local expected="$2"
  local msg="$3"
  if [[ "$got" != "$expected" ]]; then
    echo "assertion failed: $msg" >&2
    echo "  expected: $expected" >&2
    echo "  got:      $got" >&2
    exit 1
  fi
}

cd "$REPO_DIR"

bench_ndjson="$TMP_DIR/bench.ndjson"
"$TOOL" extract-bench <"$FIXTURE_DIR/bench_output_sample.txt" >"$bench_ndjson"

bench_count="$(wc -l <"$bench_ndjson" | tr -d ' ')"
assert_eq "$bench_count" "3" "bench entries count"

bench_names="$(jq -r '.bench_name' "$bench_ndjson" | sort | paste -sd, -)"
assert_eq "$bench_names" "alpha,beta,gamma" "bench names"

alpha_mean="$(jq -r 'select(.bench_name == "alpha").mean_us' "$bench_ndjson")"
assert_eq "$alpha_mean" "1.5" "alpha mean"

gamma_file="$(jq -r 'select(.bench_name == "gamma").filename' "$bench_ndjson")"
assert_eq "$gamma_file" "bench_c.mbt" "gamma filename"

coverage_files_ndjson="$TMP_DIR/coverage_files.ndjson"
"$TOOL" extract-coverage-files "$FIXTURE_DIR/coverage_coveralls_sample.json" >"$coverage_files_ndjson"

coverage_file_count="$(wc -l <"$coverage_files_ndjson" | tr -d ' ')"
assert_eq "$coverage_file_count" "2" "coverage file entries count"

foo_total="$(jq -r 'select(.filename == "foo.mbt").total_points' "$coverage_files_ndjson")"
assert_eq "$foo_total" "3" "foo total points"

foo_covered="$(jq -r 'select(.filename == "foo.mbt").covered_points' "$coverage_files_ndjson")"
assert_eq "$foo_covered" "2" "foo covered points"

foo_rate="$(jq -r 'select(.filename == "foo.mbt").line_rate' "$coverage_files_ndjson")"
assert_eq "$foo_rate" "0.6666666666666666" "foo line rate"

bar_rate="$(jq -r 'select(.filename == "bar.mbt").line_rate' "$coverage_files_ndjson")"
assert_eq "$bar_rate" "0" "bar line rate"

coverage_lines_ndjson="$TMP_DIR/coverage_lines.ndjson"
"$TOOL" extract-coverage-lines "$FIXTURE_DIR/coverage_coveralls_sample.json" >"$coverage_lines_ndjson"

coverage_line_count="$(wc -l <"$coverage_lines_ndjson" | tr -d ' ')"
assert_eq "$coverage_line_count" "3" "coverage line entries count"

line3_hits="$(jq -r 'select(.filename == "foo.mbt" and .line_no == 3).hits' "$coverage_lines_ndjson")"
assert_eq "$line3_hits" "2" "foo line3 hits"

line2_hits="$(jq -r 'select(.filename == "foo.mbt" and .line_no == 2).hits' "$coverage_lines_ndjson")"
assert_eq "$line2_hits" "0" "foo line2 hits"

echo "moon_metrics parser tests passed"

view_db="$TMP_DIR/views.sqlite"
"$TOOL" init-db --db "$view_db" >/dev/null

sqlite3 "$view_db" <<'SQL'
INSERT INTO runs (
  run_id, collected_at, git_sha, moon_version, module_name, target_hint, bench_package, coverage_package
) VALUES
  ('r1', '2026-02-01T00:00:00Z', 'sha1', 'moon x', 'm/mod', 'native/release', 'benchmarks', 'm/mod'),
  ('r2', '2026-02-02T00:00:00Z', 'sha2', 'moon x', 'm/mod', 'native/release', 'benchmarks', 'm/mod');

INSERT INTO bench_metrics (
  run_id, package, filename, bench_name,
  mean_us, min_us, max_us, std_dev_us, std_dev_pct, median_us, iqr_us,
  runs, batch_size
) VALUES
  ('r1', 'm/mod/bench', 'bench_a.mbt', 'alpha', 10.0, 9.0, 11.0, 0.5, 5.0, 10.0, 0.8, 5, 1000),
  ('r2', 'm/mod/bench', 'bench_a.mbt', 'alpha', 12.0, 11.0, 13.0, 0.7, 6.0, 12.0, 0.9, 5, 1000),
  ('r1', 'm/mod/bench', 'bench_a.mbt', 'beta', 4.0, 3.9, 4.2, 0.1, 2.5, 4.0, 0.1, 5, 1000),
  ('r2', 'm/mod/bench', 'bench_a.mbt', 'beta', 4.1, 4.0, 4.3, 0.1, 2.3, 4.1, 0.1, 5, 1000);

INSERT INTO coverage_file_metrics (
  run_id, filename, covered_points, total_points, line_rate
) VALUES
  ('r1', 'foo.mbt', 80, 100, 0.8),
  ('r2', 'foo.mbt', 75, 100, 0.75),
  ('r1', 'bar.mbt', 50, 100, 0.5),
  ('r2', 'bar.mbt', 55, 100, 0.55);
SQL

alpha_delta="$(sqlite3 "$view_db" "select printf('%.3f', delta_us) from bench_timeseries where run_id = 'r2' and bench_name = 'alpha';")"
assert_eq "$alpha_delta" "2.000" "bench_timeseries alpha delta_us"

alpha_ratio="$(sqlite3 "$view_db" "select printf('%.3f', delta_ratio) from bench_timeseries where run_id = 'r2' and bench_name = 'alpha';")"
assert_eq "$alpha_ratio" "0.200" "bench_timeseries alpha delta_ratio"

bench_reg_count="$(sqlite3 "$view_db" "select count(*) from bench_regressions_5pct;")"
assert_eq "$bench_reg_count" "1" "bench_regressions_5pct count"

drop_delta="$(sqlite3 "$view_db" "select printf('%.3f', delta_line_rate) from coverage_file_timeseries where run_id = 'r2' and filename = 'foo.mbt';")"
assert_eq "$drop_delta" "-0.050" "coverage_file_timeseries foo delta"

drop_count="$(sqlite3 "$view_db" "select count(*) from coverage_drops_1pct;")"
assert_eq "$drop_count" "1" "coverage_drops_1pct count"

summary_cov_rate="$(sqlite3 "$view_db" "select printf('%.3f', coverage_rate) from run_metrics_summary where run_id = 'r2';")"
assert_eq "$summary_cov_rate" "0.650" "run_metrics_summary coverage rate"

echo "moon_metrics view tests passed"
