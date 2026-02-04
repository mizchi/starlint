///|
fn is_ident_char(c : UInt16) -> Bool {
  (('a' : UInt16) <= c && c <= ('z' : UInt16)) ||
  (('A' : UInt16) <= c && c <= ('Z' : UInt16)) ||
  (('0' : UInt16) <= c && c <= ('9' : UInt16)) ||
  c == ('_' : UInt16)
}

///|
fn normalize_using_type_keyword(source : String) -> String {
  let mut output = source
  let mut offset = 0
  while offset < output.length() {
    let view_result : Result[StringView, Error] = try? output[offset:]
    match view_result {
      Ok(view) =>
        match view.find("using") {
          None => break
          Some(rel) => {
            let using_pos = offset + rel
            if using_pos > 0 && is_ident_char(output[using_pos - 1]) {
              offset = using_pos + 5
              continue
            }
            let using_end = using_pos + 5
            if using_end < output.length() && is_ident_char(output[using_end]) {
              offset = using_end
              continue
            }
            let after_using_result : Result[StringView, Error] = try? output[using_pos:]
            let brace_rel = match after_using_result {
              Ok(after_using) => after_using.find("{")
              Err(_) => None
            }
            match brace_rel {
              None => break
              Some(rel_brace) => {
                let brace_pos = using_pos + rel_brace
                let after_brace_result : Result[StringView, Error] = try? output[brace_pos:]
                let close_rel = match after_brace_result {
                  Ok(after_brace) => after_brace.find("}")
                  Err(_) => None
                }
                match close_rel {
                  None => break
                  Some(rel_close) => {
                    let close_pos = brace_pos + rel_close
                    let prefix_result : Result[StringView, Error] = try? output[:brace_pos +
                      1]
                    let mid_result : Result[StringView, Error] = try? output[brace_pos +
                      1:close_pos]
                    let suffix_result : Result[StringView, Error] = try? output[close_pos:]
                    match (prefix_result, mid_result, suffix_result) {
                      (Ok(prefix), Ok(mid), Ok(suffix)) => {
                        let mid_replaced = mid
                          .to_string()
                          .replace_all(old="type ", new="     ")
                        let sb = StringBuilder::new()
                        sb
                        ..write_view(prefix)
                        ..write_string(mid_replaced)
                        ..write_view(suffix)
                        output = sb.to_string()
                        offset = close_pos + 1
                      }
                      _ => break
                    }
                  }
                }
              }
            }
          }
        }
      Err(_) => break
    }
  }
  output
}

///|
fn colorize(text : String, code : String) -> String {
  let sb = StringBuilder::new()
  sb
  ..write_string("\u{1b}[")
  ..write_string(code)
  ..write_string("m")
  ..write_string(text)
  ..write_string("\u{1b}[0m")
  sb.to_string()
}

///|
fn severity_color_code(severity : @starlint.Severity) -> String {
  match severity {
    @starlint.Severity::Error => "31"
    @starlint.Severity::Warning => "33"
    @starlint.Severity::Info => "34"
  }
}

///|
fn format_diagnostic_colored(diag : @starlint.Diagnostic) -> String {
  let sb = StringBuilder::new()
  let rule_text = colorize(diag.rule_id, "36")
  let sev_label = diag.severity.to_string()
  let sev_text = colorize(sev_label, severity_color_code(diag.severity))
  sb
  ..write_string("Found ")
  ..write_string(rule_text)
  ..write_string(" (")
  ..write_string(sev_text)
  ..write_string(")")
  ..write_string(" at ")
  ..write_string(diag.loc.to_string())
  ..write_string(":\n\n")
  ..write_string(diag.message)
  match diag.detail {
    Some(detail) => sb..write_string("\n\n")..write_string(detail)
    None => ()
  }
  match diag.suggestion {
    Some(suggestion) =>
      sb..write_string("\n\nSuggestion: ")..write_string(suggestion)
    None => ()
  }
  match diag.fix {
    Some(fix) =>
      sb
      ..write_string("\n\nFix: replace ")
      ..write_string(fix.range.to_string())
      ..write_string(" with:\n")
      ..write_string(fix.replacement)
    None => ()
  }
  sb..write_string("\n")
  sb.to_string()
}

///|
fn compare_by_file(a : @starlint.Diagnostic, b : @starlint.Diagnostic) -> Int {
  let fa = a.loc.start.fname
  let fb = b.loc.start.fname
  let cmp = fa.compare(fb)
  if cmp != 0 {
    return cmp
  }
  let line_cmp = a.loc.start.lnum - b.loc.start.lnum
  if line_cmp != 0 {
    return line_cmp
  }
  a.loc.start.cnum - b.loc.start.cnum
}

///|
fn compare_by_rule(a : @starlint.Diagnostic, b : @starlint.Diagnostic) -> Int {
  let cmp = a.rule_id.compare(b.rule_id)
  if cmp != 0 {
    return cmp
  }
  compare_by_file(a, b)
}

///|
fn print_by_file(diagnostics : Array[@starlint.Diagnostic]) -> Unit {
  if diagnostics.is_empty() {
    return
  }
  diagnostics.sort_by(compare_by_file)
  let mut current = ""
  for diag in diagnostics {
    let fname = diag.loc.start.fname
    if fname != current {
      if current != "" {
        println(" ")
      }
      println(colorize(fname, "1;34"))
      current = fname
    }
    format_diagnostic_colored(diag) |> println
  }
}

///|
fn print_by_rule(diagnostics : Array[@starlint.Diagnostic]) -> Unit {
  if diagnostics.is_empty() {
    return
  }
  diagnostics.sort_by(compare_by_rule)
  let mut current = ""
  for diag in diagnostics {
    let rule_id = diag.rule_id
    if rule_id != current {
      if current != "" {
        println(" ")
      }
      println(colorize(rule_id, "1;35"))
      current = rule_id
    }
    format_diagnostic_colored(diag) |> println
  }
}

///|
fn join_strings(items : Array[String], sep : String) -> String {
  if items.is_empty() {
    return ""
  }
  let sb = StringBuilder::new()
  let mut first = true
  for item in items {
    if first {
      first = false
    } else {
      sb..write_string(sep)
    }
    sb..write_string(item)
  }
  sb.to_string()
}

///|
fn string_array_inline(items : Array[String]) -> String {
  if items.is_empty() {
    return "[]"
  }
  let sb = StringBuilder::new()
  sb..write_string("[")
  let mut first = true
  for item in items {
    if first {
      first = false
    } else {
      sb..write_string(", ")
    }
    sb..write_string("\"")
    sb..write_string(item)
    sb..write_string("\"")
  }
  sb..write_string("]")
  sb.to_string()
}

///|
fn severity_label(severity : @starlint.Severity) -> String {
  severity.to_string().to_lower()
}

///|
fn print_rules_doc(rules : Array[@starlint.Rule]) -> Unit {
  let sorted = []
  for rule in rules {
    sorted.push(rule)
  }
  sorted.sort_by((a, b) => a.id.compare(b.id))
  let recommended = @starlint.LintConfig::recommended()
  for rule in sorted {
    let (rec_enabled, rec_sev) = @starlint.resolve_rule_settings(
      rule, recommended,
    )
    let tags = if rule.tags.is_empty() {
      "(none)"
    } else {
      join_strings(rule.tags, ", ")
    }
    let default_state = if rule.enabled_by_default { "on" } else { "off" }
    let rec_state = if rec_enabled { "on" } else { "off" }
    println(rule.id)
    println("  tags: \{tags}")
    println(
      "  default: \{default_state} (\{severity_label(rule.default_severity)})",
    )
    println("  recommended: \{rec_state} (\{severity_label(rec_sev)})")
    println("  description: \{rule.description}")
    println(" ")
  }
}

///|
fn default_rules_config_json(rules : Array[@starlint.Rule]) -> String {
  let sorted = []
  for rule in rules {
    sorted.push(rule)
  }
  sorted.sort_by((a, b) => a.id.compare(b.id))
  let recommended = @starlint.LintConfig::recommended()
  let always_on = []
  let project_policy = []
  let async_rules = []
  let error_rules = []
  let fp_rules = []
  let size_rules = []
  let perf_sensitive = []
  for rule in sorted {
    let tags = rule.tags
    if tags.contains("perf") {
      perf_sensitive.push(rule.id)
    } else if tags.contains("size") {
      size_rules.push(rule.id)
    } else if tags.contains("async") {
      async_rules.push(rule.id)
    } else if tags.contains("error") {
      error_rules.push(rule.id)
    } else if tags.contains("fp") {
      fp_rules.push(rule.id)
    } else if tags.contains("module") || tags.contains("test") {
      project_policy.push(rule.id)
    } else {
      always_on.push(rule.id)
    }
  }
  let sb = StringBuilder::new()
  sb..write_string("{\n")
  sb..write_string("  \"preset\": \"recommended\",\n")
  sb..write_string("  \"ignore\": [\"target/*\", \"_build/*\"],\n")
  sb..write_string("  \"rule_groups\": {\n")
  sb..write_string("    \"always_on\": ")
  sb..write_string(string_array_inline(always_on))
  sb..write_string(",\n")
  sb..write_string("    \"project_policy\": ")
  sb..write_string(string_array_inline(project_policy))
  sb..write_string(",\n")
  sb..write_string("    \"async\": ")
  sb..write_string(string_array_inline(async_rules))
  sb..write_string(",\n")
  sb..write_string("    \"error\": ")
  sb..write_string(string_array_inline(error_rules))
  sb..write_string(",\n")
  sb..write_string("    \"fp\": ")
  sb..write_string(string_array_inline(fp_rules))
  sb..write_string(",\n")
  sb..write_string("    \"size\": ")
  sb..write_string(string_array_inline(size_rules))
  sb..write_string(",\n")
  sb..write_string("    \"perf_sensitive\": ")
  sb..write_string(string_array_inline(perf_sensitive))
  sb..write_string("\n")
  sb..write_string("  },\n")
  sb..write_string("  \"_notes\": {\n")
  sb..write_string(
    "    \"always_on\": \"Safe defaults with low false positives.\",\n",
  )
  sb..write_string(
    "    \"project_policy\": \"Team policy (docs/tests) depends on project conventions.\",\n",
  )
  sb..write_string(
    "    \"async\": \"Enable when the project uses async/task patterns.\",\n",
  )
  sb..write_string(
    "    \"error\": \"Enable to enforce consistent error-handling patterns.\",\n",
  )
  sb..write_string(
    "    \"fp\": \"Functional style improvements; enable when desired.\",\n",
  )
  sb..write_string(
    "    \"size\": \"Enable when JS bundle size is important.\",\n",
  )
  sb..write_string(
    "    \"perf_sensitive\": \"Low-level performance guidance; enable only where perf is critical.\",\n",
  )
  sb..write_string(
    "    \"preset\": \"recommended enables fp/size/async/error categories by default.\"\n",
  )
  sb..write_string("  },\n")
  sb..write_string("  \"rules\": {\n")
  let mut index = 0
  for rule in sorted {
    let (enabled, sev) = @starlint.resolve_rule_settings(rule, recommended)
    let value = if enabled { severity_label(sev) } else { "off" }
    sb..write_string("    \"")
    sb..write_string(rule.id)
    sb..write_string("\": \"")
    sb..write_string(value)
    sb..write_string("\"")
    index += 1
    if index < sorted.length() {
      sb..write_string(",")
    }
    sb..write_string("\n")
  }
  sb..write_string("  }\n")
  sb..write_string("}\n")
  sb.to_string()
}

///|
fn run_init(rules : Array[@starlint.Rule], module_root : String) -> Unit {
  let config_path = join_path(module_root, "starlint.json")
  let hidden_config = join_path(module_root, ".starlint.json")
  let legacy_config = join_path(module_root, "moonlint.json")
  let legacy_hidden = join_path(module_root, ".moonlint.json")
  if @fs.path_exists(config_path) ||
    @fs.path_exists(hidden_config) ||
    @fs.path_exists(legacy_config) ||
    @fs.path_exists(legacy_hidden) {
    println("config already exists (starlint.json or moonlint.json).")
    return
  }
  let text = default_rules_config_json(rules)
  @fs.write_string_to_file(config_path, text) catch {
    err => {
      println("failed to write starlint.json: \{err}")
      panic()
    }
  }
  println("generated starlint.json")
}

///|
fn read_mbt_file_to_impls(
  fs_path : String,
  source_name : String,
) -> (@syntax.Impls, String) raise {
  let source = @fs.read_file_to_string(fs_path)
  let normalized_source = normalize_using_type_keyword(source)
  let (impls, reports) = @parser.parse_string(
    normalized_source,
    name=source_name,
    parser=MoonYacc,
  )
  if reports.length() > 0 {
    fail(reports[0].to_string())
  }
  // println(impls.to_json().stringify(indent=2))
  return (impls, source)
}

///|
fn default_config_path(module_root : String) -> String? {
  let primary = join_path(module_root, "starlint.json")
  if @fs.path_exists(primary) {
    return Some(primary)
  }
  let hidden = join_path(module_root, ".starlint.json")
  if @fs.path_exists(hidden) {
    return Some(hidden)
  }
  let legacy = join_path(module_root, "moonlint.json")
  if @fs.path_exists(legacy) {
    return Some(legacy)
  }
  let legacy_hidden = join_path(module_root, ".moonlint.json")
  if @fs.path_exists(legacy_hidden) {
    return Some(legacy_hidden)
  }
  None
}

///|
fn resolve_config_path(module_root : String, path : String) -> String {
  if path == "" {
    return path
  }
  if is_abs_path(path) {
    path
  } else {
    join_path(module_root, path)
  }
}

///|
fn load_config(path : String) -> @starlint.LintConfig raise {
  let text = @fs.read_file_to_string(path)
  @starlint.LintConfig::from_json(text)
}

///|
fn lint_file(
  fs_path : String,
  display_path : String,
  rules : Array[@starlint.Rule],
  config : @starlint.LintConfig,
) -> Array[@starlint.Diagnostic] raise {
  let (impls, source) = read_mbt_file_to_impls(fs_path, display_path)
  let input = @starlint.LintInput::new(impls~, source~, filename=display_path)
  return @starlint.lint_with_config(input, rules, config)
}

///|
fn collect_fixes(
  diagnostics : Array[@starlint.Diagnostic],
  filename : String,
) -> Array[@starlint.Fix] {
  let fixes = []
  for diag in diagnostics {
    match diag.fix {
      Some(fix) =>
        if fix.range.start.fname == "" || fix.range.start.fname == filename {
          fixes.push(fix)
        }
      None => ()
    }
  } else {
    fixes
  }
}

///|
fn apply_fixes_to_source(
  source : String,
  fixes : Array[@starlint.Fix],
) -> (String, Int) {
  if fixes.is_empty() {
    return (source, 0)
  }
  fixes.sort_by((a, b) => b.range.start.cnum - a.range.start.cnum)
  let mut output = source
  let mut applied = 0
  let mut prev_start = output.length() + 1
  for fix in fixes {
    let start = fix.range.start.cnum
    let end = fix.range.end.cnum
    if end <= prev_start && 0 <= start && start <= end && end <= output.length() {
      let prefix_result : Result[StringView, Error] = try? output[:start]
      let suffix_result : Result[StringView, Error] = try? output[end:]
      match (prefix_result, suffix_result) {
        (Ok(prefix), Ok(suffix)) => {
          let sb = StringBuilder::new()
          sb
          ..write_view(prefix)
          ..write_string(fix.replacement)
          ..write_view(suffix)
          output = sb.to_string()
          applied += 1
          prev_start = start
        }
        _ => ()
      }
    }
  } else {
    (output, applied)
  }
}

///|
fn apply_fixes_to_file(
  fs_path : String,
  display_path : String,
  diagnostics : Array[@starlint.Diagnostic],
) -> Int raise {
  let fixes = collect_fixes(diagnostics, display_path)
  if fixes.is_empty() {
    return 0
  }
  let source = @fs.read_file_to_string(fs_path)
  let (new_source, applied) = apply_fixes_to_source(source, fixes)
  if applied > 0 && new_source != source {
    @fs.write_string_to_file(fs_path, new_source)
  }
  applied
}

///|
fn resolve_start_dir(start_dir : String) -> String {
  let base = match @sys.get_env_var("PWD") {
    Some(path) => path
    None =>
      match @sys.get_env_var("INIT_CWD") {
        Some(path) => path
        None => "."
      }
  }
  if start_dir == "" {
    return base
  }
  if is_abs_path(start_dir) {
    start_dir
  } else {
    join_path(base, start_dir)
  }
}

///|
fn resolve_module_root(start_dir : String) -> String raise Error {
  match find_module_root(start_dir) {
    Some(root) => root
    None => fail("moon.mod.json not found from \{start_dir}")
  }
}

///|
fn build_file_entries_from_args(
  filenames : Array[String],
  start_dir : String,
  module_root : String,
) -> Array[(String, String)] {
  let entries = []
  for filename in filenames {
    let fs_path = resolve_path(start_dir, filename)
    let rel_path = match path_relative_to_root(fs_path, module_root) {
      Some(rel) => if rel == "" { filename } else { strip_dot_slash(rel) }
      None => filename
    }
    entries.push((fs_path, rel_path))
  } else {
    entries
  }
}

///|
fn build_file_entries_from_module(
  module_root : String,
  base_fs : String,
  base_rel : String,
) -> Array[(String, String)] raise Error {
  let rel_paths = get_mbt_path_set_from_base(base_fs, base_rel)
  let entries = []
  for rel_path in rel_paths {
    let fs_path = join_path(module_root, rel_path)
    entries.push((fs_path, rel_path))
  } else {
    entries
  }
}

///|
fn run_with_start_dir(argv : Array[String], start_dir : String) -> Unit {
  if argv.length() > 0 && !argv[0].has_prefix("-") {
    let cmd = argv[0]
    let rules = @lint.rules()
    if cmd == "doc" {
      print_rules_doc(rules)
      return
    }
    if cmd == "init" {
      let module_root = resolve_module_root(start_dir) catch {
        err => {
          println("failed to find module root: \{err}")
          panic()
        }
      }
      run_init(rules, module_root)
      return
    }
  }
  let apply_fix = @ref.new(false)
  let config_path = @ref.new("")
  let by_file = @ref.new(false)
  let by_rule = @ref.new(false)
  let spec : Array[(String, String, @ArgParser.Spec, String)] = [
    ("--fix", "-f", @ArgParser.Spec::Set(apply_fix), "apply autofixes"),
    (
      "--config",
      "-c",
      @ArgParser.Spec::Set_string(config_path),
      "config file path",
    ),
    ("--by-file", "", @ArgParser.Spec::Set(by_file), "group by file (default)"),
    ("--by-rule", "", @ArgParser.Spec::Set(by_rule), "group by rule"),
  ]
  let filenames = []
  let usage =
    #| usage: 
    #|   starlint [--fix] [--config <file>] [--by-file|--by-rule] <file1> <file2> ...
    #|   starlint init
    #|   starlint doc
  @ArgParser.parse(spec, filename => filenames.push(filename), usage, argv) catch {
    err => {
      println(err)
      panic()
    }
  }
  let module_root = resolve_module_root(start_dir) catch {
    err => {
      println("failed to find module root: \{err}")
      panic()
    }
  }
  let module_info = load_module_info(module_root) catch {
    err => {
      println("failed to load module info: \{err}")
      panic()
    }
  }
  let base_rel = get_src_location(module_info)
  let base_fs = if base_rel == "." || base_rel == "" {
    module_root
  } else {
    join_path(module_root, base_rel)
  }
  let file_entries = if filenames.length() == 0 {
    build_file_entries_from_module(module_root, base_fs, base_rel) catch {
      err => {
        println("failed when finding source files: \{err}")
        panic()
      }
    }
  } else {
    build_file_entries_from_args(filenames, start_dir, module_root)
  }
  let rules = @lint.rules()
  let config = match resolve_config_path(module_root, config_path.val) {
    "" =>
      match default_config_path(module_root) {
        Some(path) =>
          load_config(path) catch {
            err => {
              println("failed to load config: \{err}")
              panic()
            }
          }
        None => @starlint.LintConfig::recommended()
      }
    path =>
      load_config(path) catch {
        err => {
          println("failed to load config: \{err}")
          panic()
        }
      }
  }
  let use_by_rule = if by_file.val { false } else { by_rule.val }
  let diagnostics = []
  for entry in file_entries {
    let (fs_path, display_path) = entry
    let file_config = config.for_file(display_path)
    if file_config.is_ignored(display_path) {
      continue
    }
    let mut file_diagnostics = lint_file(
      fs_path, display_path, rules, file_config,
    ) catch {
      err => {
        println(err)
        panic()
      }
    }
    if apply_fix.val {
      let applied = apply_fixes_to_file(fs_path, display_path, file_diagnostics) catch {
        err => {
          println(err)
          panic()
        }
      }
      if applied > 0 {
        let refreshed_config = config.for_file(display_path)
        file_diagnostics = lint_file(
          fs_path, display_path, rules, refreshed_config,
        ) catch {
          err => {
            println(err)
            panic()
          }
        }
        println("Applied \{applied} fixes in \{display_path}")
      }
    }
    for diag in file_diagnostics {
      diagnostics.push(diag)
    }
  }
  // make output more human-friendly
  println(" ")
  if use_by_rule {
    print_by_rule(diagnostics)
  } else {
    print_by_file(diagnostics)
  }
}

///|
pub fn run(args : Array[String], start_dir? : String = "") -> Unit {
  run_with_start_dir(args, resolve_start_dir(start_dir))
}

///|
fn main {
  let argv = @sys.get_cli_args()[1:].to_array()
  run(argv)
}
