///|
fn lint_bench_file_path() -> String {
  match @sys.get_env_var("STARLINT_LINT_BENCH_FILE") {
    Some(value) => value
    None => "warnings_fixtures_test.mbt"
  }
}

///|
fn lint_bench_repeat() -> Int {
  let default_repeat = 1
  let repeat = match @sys.get_env_var("STARLINT_LINT_BENCH_REPEAT") {
    Some(value) => parse_int_or(default_repeat, value)
    None => default_repeat
  }
  if repeat < 1 {
    1
  } else {
    repeat
  }
}

///|
fn load_lint_bench_source() -> (String, String) {
  let filename = lint_bench_file_path()
  let source = @fs.read_file_to_string(filename) catch {
    err => {
      println("failed to read \{filename}: \{err}")
      panic()
    }
  }
  let repeat = lint_bench_repeat()
  if repeat <= 1 {
    (filename, source)
  } else {
    let sb = StringBuilder::new()
    for _ in 0..<repeat {
      sb..write_string(source)..write_char('\n')
    }
    (filename, sb.to_string())
  }
}

///|
fn parse_impls_for_bench(source : String, filename : String) -> @syntax.Impls {
  let (impls, reports) = @starlint.parse_string_for_lint(
    source,
    name=filename,
    parser=MoonYacc,
  )
  if reports.length() > 0 {
    println(reports[0].to_string())
    panic()
  }
  impls
}

///|
fn take_rules(
  rules : Array[@starlint.Rule],
  size : Int,
) -> Array[@starlint.Rule] {
  let length = rules.length()
  let limit = if size < 0 { 0 } else if size > length { length } else { size }
  rules[0:limit].to_array()
}

///|
fn rule_has_any_tag(rule : @starlint.Rule, tags : Array[String]) -> Bool {
  for tag in tags {
    if rule.tags.contains(tag) {
      return true
    }
  }
  false
}

///|
fn filter_rules_by_tag(
  rules : Array[@starlint.Rule],
  tag : String,
) -> Array[@starlint.Rule] {
  let out = []
  for rule in rules {
    if rule.tags.contains(tag) {
      out.push(rule)
    }
  } else {
    out
  }
}

///|
fn filter_rules_by_tags(
  rules : Array[@starlint.Rule],
  tags : Array[String],
) -> Array[@starlint.Rule] {
  let out = []
  for rule in rules {
    if rule_has_any_tag(rule, tags) {
      out.push(rule)
    }
  } else {
    out
  }
}

///|
fn bench_lint_rules(
  bench : @bench.T,
  input : @starlint.LintInput,
  rules : Array[@starlint.Rule],
  name : String,
  count : UInt,
) -> Unit {
  let config = @starlint.LintConfig::empty()
  bench.bench(
    fn() {
      let diagnostics = @starlint.lint_with_config(input, rules, config)
      bench.keep(diagnostics.length())
    },
    name~,
    count~,
  )
}

///|
fn bench_lint_prefix_rules(
  bench : @bench.T,
  input : @starlint.LintInput,
  rules : Array[@starlint.Rule],
  size : Int,
  count : UInt,
) -> Unit {
  let subset = take_rules(rules, size)
  bench_lint_rules(bench, input, subset, "lint_first_\{size}", count)
}

///|
test (bench : @bench.T) {
  let count = bench_count()
  let (filename, source) = load_lint_bench_source()
  let impls = parse_impls_for_bench(source, filename)
  let input = @starlint.LintInput::new(impls~, source~, filename~)
  let all_rules = @lint.rules()
  bench_lint_rules(bench, input, all_rules, "lint_all_rules", count)
  bench_lint_prefix_rules(bench, input, all_rules, 1, count)
  bench_lint_prefix_rules(bench, input, all_rules, 5, count)
  bench_lint_prefix_rules(bench, input, all_rules, 10, count)
  bench_lint_prefix_rules(bench, input, all_rules, 20, count)
  bench_lint_prefix_rules(bench, input, all_rules, 30, count)
  let fp_rules = filter_rules_by_tag(all_rules, "fp")
  bench_lint_rules(bench, input, fp_rules, "lint_tag_fp", count)
  let perf_rules = filter_rules_by_tag(all_rules, "perf")
  bench_lint_rules(bench, input, perf_rules, "lint_tag_perf", count)
  let async_rules = filter_rules_by_tag(all_rules, "async")
  bench_lint_rules(bench, input, async_rules, "lint_tag_async", count)
  let module_rules = filter_rules_by_tag(all_rules, "module")
  bench_lint_rules(bench, input, module_rules, "lint_tag_module", count)
  let error_rules = filter_rules_by_tag(all_rules, "error")
  bench_lint_rules(bench, input, error_rules, "lint_tag_error", count)
  let size_rules = filter_rules_by_tag(all_rules, "size")
  bench_lint_rules(bench, input, size_rules, "lint_tag_size", count)
  let test_rules = filter_rules_by_tag(all_rules, "test")
  bench_lint_rules(bench, input, test_rules, "lint_tag_test", count)
  let fp_perf_rules = filter_rules_by_tags(all_rules, ["fp", "perf"])
  bench_lint_rules(bench, input, fp_perf_rules, "lint_tags_fp_perf", count)
  for rule in all_rules {
    let name = "lint_rule_\{rule.id}"
    bench_lint_rules(bench, input, [rule], name, count)
  }
}
