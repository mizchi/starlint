///|
test "build_command: baseline --compare parses correctly" {
  let cmd = build_command()
  let matches = cmd.parse(argv=["baseline", "--compare", "baseline.json"], env={}) catch {
    err => {
      println(err)
      panic()
    }
  }
  guard matches.subcommand is Some(("baseline", sub_matches))
  let compare = match sub_matches.values.get("compare") {
    Some([val, ..]) => val
    _ => ""
  }
  inspect(compare, content="baseline.json")
}

///|
test "build_command: baseline -c parses correctly" {
  let cmd = build_command()
  let matches = cmd.parse(argv=["baseline", "-c", "path/to/baseline.json"], env={}) catch {
    err => {
      println(err)
      panic()
    }
  }
  guard matches.subcommand is Some(("baseline", sub_matches))
  let compare = match sub_matches.values.get("compare") {
    Some([val, ..]) => val
    _ => ""
  }
  inspect(compare, content="path/to/baseline.json")
}

///|
test "build_command: baseline without compare" {
  let cmd = build_command()
  let matches = cmd.parse(argv=["baseline"], env={}) catch {
    err => {
      println(err)
      panic()
    }
  }
  guard matches.subcommand is Some(("baseline", sub_matches))
  let compare = match sub_matches.values.get("compare") {
    Some([val, ..]) => val
    _ => ""
  }
  inspect(compare, content="")
}

///|
test "build_command: lint with flags" {
  let cmd = build_command()
  let matches = cmd.parse(argv=["--fix", "--rule", "some_rule", "a.mbt"], env={}) catch {
    err => {
      println(err)
      panic()
    }
  }
  inspect(matches.flags.get("fix"), content="Some(true)")
  let rule = match matches.values.get("rule") {
    Some([val, ..]) => val
    _ => ""
  }
  inspect(rule, content="some_rule")
  let files = matches.values.get("files").unwrap_or([])
  inspect(files, content="[\"a.mbt\"]")
}

///|
test "normalize_lint_targets: single dot means module scan" {
  let actual = normalize_lint_targets(["."])
  inspect(actual, content="[]")
}

///|
test "normalize_lint_targets: file path is kept" {
  let actual = normalize_lint_targets(["foo.mbt"])
  inspect(actual, content="[\"foo.mbt\"]")
}

///|
test "run_with_start_dir: empty args prints help and returns" {
  let fs = @vfs.MemVFS::new()
  run_with_start_dir(fs, [], "/repo")
}

///|
test "analyze_compare_path: default latest path" {
  let fs = @vfs.MemVFS::new()
  fs.write_string("/repo/.starlint/latest.json", "{}")
  let actual = analyze_compare_path(fs, "/repo", "")
  inspect(actual, content="/repo/.starlint/latest.json")
}

///|
test "analyze_compare_path: default current hash path" {
  let fs = @vfs.MemVFS::new()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string("/repo/.git/refs/heads/main", "abc123\n")
  fs.write_string("/repo/.starlint/abc123.json", "{}")
  let actual = analyze_compare_path(fs, "/repo", "")
  inspect(actual, content="/repo/.starlint/abc123.json")
}

///|
test "analyze_compare_path: default fallback latest path" {
  let fs = @vfs.MemVFS::new()
  let actual = analyze_compare_path(fs, "/repo", "")
  inspect(actual, content="/repo/.starlint/latest.json")
}

///|
test "analyze_compare_path: relative path" {
  let fs = @vfs.MemVFS::new()
  let actual = analyze_compare_path(fs, "/repo", "tmp/base.json")
  inspect(actual, content="/repo/tmp/base.json")
}

///|
test "analyze_compare_path: absolute path" {
  let fs = @vfs.MemVFS::new()
  let actual = analyze_compare_path(fs, "/repo", "/tmp/base.json")
  inspect(actual, content="/tmp/base.json")
}

///|
test "read_mbt_file_to_impls: fallback parser handles nobreak" {
  let fs = @vfs.MemVFS::new()
  let source =
    #|///|
    #|pub fn lint_with_config() -> Array[Int] {
    #|  let diagnostics = Array::new(capacity=0)
    #|  let rules = [1]
    #|  for rule in rules {
    #|    diagnostics.push(rule)
    #|  } nobreak {
    #|    diagnostics
    #|  }
    #|}
    #|
  fs.write_string("/repo/engine_like.mbt", source)
  let result : Result[(@syntax.Impls, String), Error] = try? read_mbt_file_to_impls(
    fs, "/repo/engine_like.mbt", "engine_like.mbt",
  )
  guard result is Ok((impls, parsed_source)) &&
    impls.length() > 0 &&
    parsed_source == source else {
    fail("expected parser to handle nobreak source")
  }
}

///|
fn dry_run_test_source_before() -> String {
  let text =
    #|fn main {
    #|  let x = if cond { true } else { false }
    #|}
  text
}

///|
fn dry_run_test_source_after() -> String {
  let text =
    #|fn main {
    #|  let x = cond
    #|}
  text
}

///|
fn setup_fix_test_module(fs : @vfs.MemVFS) -> Unit {
  let module_info =
    #|{"name":"tmp/mod","source":"."}
  fs.add_file("/repo/moon.mod.json", module_info)
  fs.add_file("/repo/a.mbt", dry_run_test_source_before())
}

///|
test "run_with_start_dir: --fix applies file changes" {
  let fs = @vfs.MemVFS::new()
  setup_fix_test_module(fs)
  run_with_start_dir(
    fs,
    ["--fix", "--rule", "boolean_if_true_false", "a.mbt"],
    "/repo",
  )
  let actual = fs.read_string("/repo/a.mbt")
  inspect(actual, content=dry_run_test_source_after())
}

///|
test "run_with_start_dir: --fix --dry-run does not write file" {
  let fs = @vfs.MemVFS::new()
  setup_fix_test_module(fs)
  run_with_start_dir(
    fs,
    ["--fix", "--dry-run", "--rule", "boolean_if_true_false", "a.mbt"],
    "/repo",
  )
  let actual = fs.read_string("/repo/a.mbt")
  inspect(actual, content=dry_run_test_source_before())
}

///|
test "format_dry_run_preview: includes old/new snippets" {
  let source = dry_run_test_source_before()
  let (impls, _) = @lintlib.parse_string_for_lint(source, name="a.mbt")
  let input = @lintlib.LintInput::new(impls~, source~, filename="a.mbt")
  let diagnostics = @lintlib.lint_with_config(
    input,
    @lint.rules(),
    @lintlib.LintConfig::recommended(),
  ).filter(diag => diag.rule_id == "boolean_if_true_false")
  let fixes = collect_fixes(diagnostics, "a.mbt")
  let preview = format_dry_run_preview(source, "a.mbt", fixes, fixes.length())
  assert_true(preview.contains("Dry-run preview for a.mbt"))
  assert_true(preview.contains("old: if cond { true } else { false }"))
  assert_true(preview.contains("new: cond"))
}
