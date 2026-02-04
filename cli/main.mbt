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
fn severity_color_code(severity : @moonlint.Severity) -> String {
  match severity {
    @moonlint.Severity::Error => "31"
    @moonlint.Severity::Warning => "33"
    @moonlint.Severity::Info => "34"
  }
}

///|
fn format_diagnostic_colored(diag : @moonlint.Diagnostic) -> String {
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
fn compare_by_file(a : @moonlint.Diagnostic, b : @moonlint.Diagnostic) -> Int {
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
fn compare_by_rule(a : @moonlint.Diagnostic, b : @moonlint.Diagnostic) -> Int {
  let cmp = a.rule_id.compare(b.rule_id)
  if cmp != 0 {
    return cmp
  }
  compare_by_file(a, b)
}

///|
fn print_by_file(diagnostics : Array[@moonlint.Diagnostic]) -> Unit {
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
fn print_by_rule(diagnostics : Array[@moonlint.Diagnostic]) -> Unit {
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
fn severity_label(severity : @moonlint.Severity) -> String {
  severity.to_string().to_lower()
}

///|
fn print_rules_doc(rules : Array[@moonlint.Rule]) -> Unit {
  let sorted = []
  for rule in rules {
    sorted.push(rule)
  }
  sorted.sort_by((a, b) => a.id.compare(b.id))
  let recommended = @moonlint.LintConfig::recommended()
  for rule in sorted {
    let (rec_enabled, rec_sev) = @moonlint.resolve_rule_settings(
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
fn default_rules_config_json(rules : Array[@moonlint.Rule]) -> String {
  let sorted = []
  for rule in rules {
    sorted.push(rule)
  }
  sorted.sort_by((a, b) => a.id.compare(b.id))
  let recommended = @moonlint.LintConfig::recommended()
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
    let (enabled, sev) = @moonlint.resolve_rule_settings(rule, recommended)
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
fn run_init(rules : Array[@moonlint.Rule]) -> Unit {
  let config_path = "moonlint.json"
  if @fs.path_exists(config_path) {
    println("moonlint.json already exists.")
    return
  }
  let text = default_rules_config_json(rules)
  @fs.write_string_to_file(config_path, text) catch {
    err => {
      println("failed to write moonlint.json: \{err}")
      panic()
    }
  }
  println("generated moonlint.json")
}

///|
fn read_mbt_file_to_impls(filename : String) -> (@syntax.Impls, String) raise {
  let source = @fs.read_file_to_string(filename)
  let normalized_source = normalize_using_type_keyword(source)
  let (impls, reports) = @parser.parse_string(
    normalized_source,
    name=filename,
    parser=MoonYacc,
  )
  if reports.length() > 0 {
    fail(reports[0].to_string())
  }
  // println(impls.to_json().stringify(indent=2))
  return (impls, source)
}

///|
fn default_config_path() -> String? {
  if @fs.path_exists("moonlint.json") {
    Some("moonlint.json")
  } else if @fs.path_exists(".moonlint.json") {
    Some(".moonlint.json")
  } else {
    None
  }
}

///|
fn load_config(path : String) -> @moonlint.LintConfig raise {
  let text = @fs.read_file_to_string(path)
  @moonlint.LintConfig::from_json(text)
}

///|
fn lint_file(
  filename : String,
  rules : Array[@moonlint.Rule],
  config : @moonlint.LintConfig,
) -> Array[@moonlint.Diagnostic] raise {
  let (impls, source) = read_mbt_file_to_impls(filename)
  let input = @moonlint.LintInput::new(impls~, source~, filename~)
  return @moonlint.lint_with_config(input, rules, config)
}

///|
fn collect_fixes(
  diagnostics : Array[@moonlint.Diagnostic],
  filename : String,
) -> Array[@moonlint.Fix] {
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
  fixes : Array[@moonlint.Fix],
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
  filename : String,
  diagnostics : Array[@moonlint.Diagnostic],
) -> Int raise {
  let fixes = collect_fixes(diagnostics, filename)
  if fixes.is_empty() {
    return 0
  }
  let source = @fs.read_file_to_string(filename)
  let (new_source, applied) = apply_fixes_to_source(source, fixes)
  if applied > 0 && new_source != source {
    @fs.write_string_to_file(filename, new_source)
  }
  applied
}

///|
fn main {
  let argv = @sys.get_cli_args()[1:].to_array()
  if argv.length() > 0 && !argv[0].has_prefix("-") {
    let cmd = argv[0]
    let rules = @lint.rules()
    if cmd == "init" {
      run_init(rules)
      return
    }
    if cmd == "doc" {
      print_rules_doc(rules)
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
    #|   moonlint.exe [--fix] [--config <file>] [--by-file|--by-rule] <file1> <file2> ...
    #|   moonlint.exe init
    #|   moonlint.exe doc
  @ArgParser.parse(spec, filename => filenames.push(filename), usage, argv) catch {
    err => {
      println(err)
      panic()
    }
  }
  if filenames.length() == 0 {
    let base = get_src_location(load_module_info()) catch {
      err => {
        println("failed to load module info: \{err}")
        panic()
      }
    }
    let mbt_set = get_mbt_path_set_from_base(base) catch {
      err => {
        println("failed when finding source files: \{err}")
        panic()
      }
    }
    for filename in mbt_set {
      filenames.push(filename)
    }
  }
  let rules = @lint.rules()
  let config = match config_path.val {
    "" =>
      match default_config_path() {
        Some(path) =>
          load_config(path) catch {
            err => {
              println("failed to load config: \{err}")
              panic()
            }
          }
        None => @moonlint.LintConfig::recommended()
      }
    _ =>
      load_config(config_path.val) catch {
        err => {
          println("failed to load config: \{err}")
          panic()
        }
      }
  }
  let use_by_rule = if by_file.val { false } else { by_rule.val }
  let diagnostics = []
  for filename in filenames {
    let file_config = config.for_file(filename)
    if file_config.is_ignored(filename) {
      continue
    }
    let mut file_diagnostics = lint_file(filename, rules, file_config) catch {
      err => {
        println(err)
        panic()
      }
    }
    if apply_fix.val {
      let applied = apply_fixes_to_file(filename, file_diagnostics) catch {
        err => {
          println(err)
          panic()
        }
      }
      if applied > 0 {
        let refreshed_config = config.for_file(filename)
        file_diagnostics = lint_file(filename, rules, refreshed_config) catch {
          err => {
            println(err)
            panic()
          }
        }
        println("Applied \{applied} fixes in \{filename}")
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
