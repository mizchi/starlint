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
      sb..write_string("\n\nSuggestion:\n")..write_string(suggestion)
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
  sb.write_string("\n")
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
      sb.write_string(sep)
    }
    sb.write_string(item)
  }
  sb.to_string()
}

///|
fn string_array_inline(items : Array[String]) -> String {
  if items.is_empty() {
    return "[]"
  }
  let sb = StringBuilder::new()
  sb.write_string("[")
  let mut first = true
  for item in items {
    if first {
      first = false
    } else {
      sb.write_string(", ")
    }
    sb.write_string("\"")
    sb.write_string(item)
    sb.write_string("\"")
  }
  sb.write_string("]")
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
  sb.write_string("{\n")
  sb.write_string("  \"preset\": \"recommended\",\n")
  sb.write_string("  \"ignore\": [\"target/*\", \"_build/*\"],\n")
  sb.write_string("  \"rule_groups\": {\n")
  sb.write_string("    \"always_on\": ")
  sb.write_string(string_array_inline(always_on))
  sb.write_string(",\n")
  sb.write_string("    \"project_policy\": ")
  sb.write_string(string_array_inline(project_policy))
  sb.write_string(",\n")
  sb.write_string("    \"async\": ")
  sb.write_string(string_array_inline(async_rules))
  sb.write_string(",\n")
  sb.write_string("    \"error\": ")
  sb.write_string(string_array_inline(error_rules))
  sb.write_string(",\n")
  sb.write_string("    \"fp\": ")
  sb.write_string(string_array_inline(fp_rules))
  sb.write_string(",\n")
  sb.write_string("    \"size\": ")
  sb.write_string(string_array_inline(size_rules))
  sb.write_string(",\n")
  sb.write_string("    \"perf_sensitive\": ")
  sb.write_string(string_array_inline(perf_sensitive))
  sb.write_string("\n")
  sb.write_string("  },\n")
  sb.write_string("  \"_notes\": {\n")
  sb.write_string(
    "    \"always_on\": \"Safe defaults with low false positives.\",\n",
  )
  sb.write_string(
    "    \"project_policy\": \"Team policy (docs/tests) depends on project conventions.\",\n",
  )
  sb.write_string(
    "    \"async\": \"Enable when the project uses async/task patterns.\",\n",
  )
  sb.write_string(
    "    \"error\": \"Enable to enforce consistent error-handling patterns.\",\n",
  )
  sb.write_string(
    "    \"fp\": \"Functional style improvements; enable when desired.\",\n",
  )
  sb.write_string(
    "    \"size\": \"Enable when JS bundle size is important.\",\n",
  )
  sb.write_string(
    "    \"perf_sensitive\": \"Low-level performance guidance; enable only where perf is critical.\",\n",
  )
  sb.write_string(
    "    \"preset\": \"recommended enables fp/size/async/error categories by default.\"\n",
  )
  sb.write_string("  },\n")
  sb.write_string("  \"rules\": {\n")
  let mut index = 0
  for rule in sorted {
    let (enabled, sev) = @starlint.resolve_rule_settings(rule, recommended)
    let value = if enabled { severity_label(sev) } else { "off" }
    sb.write_string("    \"")
    sb.write_string(rule.id)
    sb.write_string("\": \"")
    sb.write_string(value)
    sb.write_string("\"")
    index += 1
    if index < sorted.length() {
      sb.write_string(",")
    }
    sb.write_string("\n")
  }
  sb.write_string("  }\n")
  sb.write_string("}\n")
  sb.to_string()
}

///|
fn[FS : @vfs.VFS] run_init(
  fs : FS,
  rules : Array[@starlint.Rule],
  module_root : String,
) -> Unit {
  let config_path = join_path(module_root, "starlint.json")
  let hidden_config = join_path(module_root, ".starlint.json")
  if fs.path_exists(config_path) || fs.path_exists(hidden_config) {
    println("config already exists (starlint.json).")
    return
  }
  let text = default_rules_config_json(rules)
  fs.write_string(config_path, text) catch {
    err => {
      println("failed to write starlint.json: \{err}")
      panic()
    }
  }
  println("generated starlint.json")
}

///|
fn[FS : @vfs.VFS] read_mbt_file_to_impls(
  fs : FS,
  fs_path : String,
  source_name : String,
) -> (@syntax.Impls, String) raise {
  let source = fs.read_string(fs_path)
  let (impls, reports) = @starlint.parse_string_for_lint(
    source,
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
fn get_module_name(module_info : Json) -> String {
  if module_info is Object(module_info) &&
    module_info.get("name") is Some(String(name)) {
    name
  } else {
    "unknown"
  }
}

///|
fn package_name_for_file(module_name : String, display_path : String) -> String {
  match display_path.rev_find("/") {
    None => module_name
    Some(idx) => {
      let prefix_result : Result[StringView, Error] = try? display_path[:idx]
      match prefix_result {
        Ok(view) => {
          let dir = view.to_string()
          if dir == "" {
            module_name
          } else {
            module_name + "/" + dir
          }
        }
        Err(_) => module_name
      }
    }
  }
}

///|
fn type_short_name(ty : @syntax.Type) -> String? {
  match ty {
    @syntax.Type::Name(constr_id~, ..) =>
      constr_id |> @starlint.constr_id_right_name |> Some
    @syntax.Type::Object(constr_id) =>
      constr_id |> @starlint.constr_id_right_name |> Some
    _ => None
  }
}

///|
fn format_fun_decl_name(fun_decl : @syntax.FunDecl) -> String {
  let base = fun_decl.name.name
  match fun_decl.type_name {
    Some(type_name) => "\{@starlint.type_name_right_name(type_name)}::\{base}"
    None => base
  }
}

///|
fn format_impl_method_name(
  self_ty : @syntax.Type?,
  method_name : @syntax.Binder,
) -> String {
  let base = method_name.name
  match self_ty {
    Some(ty) =>
      match type_short_name(ty) {
        Some(type_name) => "\{type_name}::\{base}"
        None => base
      }
    None => base
  }
}

///|
fn is_public_vis(vis : @syntax.Visibility) -> Bool {
  match vis {
    @syntax.Visibility::Pub(..) => true
    _ => false
  }
}

///|
fn is_check_style_test_name(name : String) -> Bool {
  let lower = name.to_lower()
  lower.contains("check")
}

///|
priv struct AiNames {
  pub_functions : Array[String]
  priv_functions : Array[String]
  tests : Array[String]
  check_style_tests : Array[String]
  unnamed_tests : Int
}

///|
priv struct DocTestInfo {
  tests : Array[String]
  check_style_tests : Array[String]
  unnamed_tests : Int
  block_count : Int
}

///|
fn strip_doc_prefix(line : String) -> String {
  if line.has_prefix("///") {
    let rest_result : Result[StringView, Error] = try? line[3:]
    match rest_result {
      Ok(rest) => rest.to_string().trim().to_string()
      Err(_) => line
    }
  } else {
    line
  }
}

///|
fn is_test_line(trimmed : String) -> Bool {
  trimmed.has_prefix("test ") ||
  trimmed.has_prefix("test{") ||
  trimmed.has_prefix("async test ") ||
  trimmed.has_prefix("async test{")
}

///|
fn extract_named_test(line : String) -> String? {
  let trimmed = line.trim().to_string()
  match trimmed.find("\"") {
    None => None
    Some(start) => {
      let rest_result : Result[StringView, Error] = try? trimmed[start + 1:]
      match rest_result {
        Ok(rest) =>
          match rest.find("\"") {
            Some(end_rel) => {
              let name_result : Result[StringView, Error] = try? rest[:end_rel]
              match name_result {
                Ok(view) => Some(view.to_string())
                Err(_) => None
              }
            }
            None => None
          }
        Err(_) => None
      }
    }
  }
}

///|
fn extract_doc_tests(source : String, allow_plain_blocks : Bool) -> DocTestInfo {
  let tests = Array::new(capacity=4)
  let check_style_tests = Array::new(capacity=2)
  let mut unnamed_tests = 0
  let mut block_count = 0
  let mut in_block = false
  for part in source.split("\n") {
    let line = part.to_string()
    let trimmed = line.trim().to_string()
    let has_doc_prefix = trimmed.has_prefix("///")
    let content = if has_doc_prefix {
      strip_doc_prefix(trimmed).trim().to_string()
    } else {
      trimmed
    }
    if content.has_prefix("```") {
      if !allow_plain_blocks && !has_doc_prefix {
        continue
      }
      if !in_block {
        if content.has_prefix("```mbt") &&
          (content.contains("test") || content.contains("check")) {
          in_block = true
          block_count += 1
        }
      } else {
        in_block = false
      }
      continue
    }
    if in_block && is_test_line(content) {
      if !allow_plain_blocks && !has_doc_prefix {
        continue
      }
      match extract_named_test(content) {
        Some(name) => {
          tests.push(name)
          if is_check_style_test_name(name) {
            check_style_tests.push(name)
          }
        }
        None => unnamed_tests += 1
      }
    }
  } else {
    DocTestInfo::{ tests, check_style_tests, unnamed_tests, block_count }
  }
}

///|
fn collect_ai_names(impls : @syntax.Impls) -> AiNames {
  let pub_functions = Array::new(capacity=8)
  let priv_functions = Array::new(capacity=8)
  let tests = Array::new(capacity=4)
  let check_style_tests = Array::new(capacity=2)
  let mut unnamed_tests = 0
  for impl_ in impls {
    match impl_ {
      @syntax.Impl::TopFuncDef(fun_decl~, ..) => {
        let name = format_fun_decl_name(fun_decl)
        if is_public_vis(fun_decl.vis) {
          pub_functions.push(name)
        } else {
          priv_functions.push(name)
        }
      }
      @syntax.Impl::TopImpl(self_ty~, method_name~, vis~, ..) => {
        let name = format_impl_method_name(self_ty, method_name)
        if is_public_vis(vis) {
          pub_functions.push(name)
        } else {
          priv_functions.push(name)
        }
      }
      @syntax.Impl::TopView(view_func_name~, vis~, ..) => {
        let name = view_func_name.name
        if is_public_vis(vis) {
          pub_functions.push(name)
        } else {
          priv_functions.push(name)
        }
      }
      @syntax.Impl::TopTest(name~, ..) =>
        match name {
          Some((test_name, _)) => {
            tests.push(test_name)
            if is_check_style_test_name(test_name) {
              check_style_tests.push(test_name)
            }
          }
          None => unnamed_tests += 1
        }
      _ => ()
    }
  } else {
    AiNames::{
      pub_functions,
      priv_functions,
      tests,
      check_style_tests,
      unnamed_tests,
    }
  }
}

///|
fn[FS : @vfs.VFS] print_ai_metadata(
  fs : FS,
  file_entries : Array[(String, String)],
  doc_entries : Array[String],
  module_name : String,
  module_root : String,
) -> Unit {
  let sb = StringBuilder::new()
  sb
  ..write_string("AI Review Metadata\n")
  ..write_string("module: ")
  ..write_string(module_name)
  ..write_string("\n")
  ..write_string("instructions:\n")
  ..write_string(
    "- Infer module purpose from module/file/function/test names.\n",
  )
  ..write_string(
    "- Ensure test names describe behavior; avoid check-style phrasing.\n",
  )
  ..write_string(
    "- Follow TDD principle: test names should describe what, not how.\n",
  )
  ..write_string(
    "- Flag public APIs without tests or doc tests in the same module.\n",
  )
  ..write_string(
    "- Call out vague module/file names (util/misc/helper) that hide intent.\n",
  )
  ..write_string("\nfiles:\n")
  for entry in file_entries {
    let (fs_path, display_path) = entry
    let package_name = package_name_for_file(module_name, display_path)
    let parse_result : Result[(@syntax.Impls, String), Error] = try? read_mbt_file_to_impls(
      fs, fs_path, display_path,
    )
    match parse_result {
      Ok((impls, source)) => {
        let names = collect_ai_names(impls)
        names.pub_functions.sort_by((a, b) => a.compare(b))
        names.priv_functions.sort_by((a, b) => a.compare(b))
        names.tests.sort_by((a, b) => a.compare(b))
        names.check_style_tests.sort_by((a, b) => a.compare(b))
        sb
        ..write_string("- file: ")
        ..write_string(display_path)
        ..write_string("\n")
        sb
        ..write_string("  package: ")
        ..write_string(package_name)
        ..write_string("\n")
        sb.write_string("  public functions:\n")
        if names.pub_functions.is_empty() {
          sb.write_string("    - (none)\n")
        } else {
          for name in names.pub_functions {
            sb..write_string("    - ")..write_string(name)..write_string("\n")
          }
        }
        sb.write_string("  private functions:\n")
        if names.priv_functions.is_empty() {
          sb.write_string("    - (none)\n")
        } else {
          for name in names.priv_functions {
            sb..write_string("    - ")..write_string(name)..write_string("\n")
          }
        }
        sb.write_string("  tests:\n")
        if names.tests.is_empty() {
          sb.write_string("    - (none)\n")
        } else {
          for name in names.tests {
            sb..write_string("    - ")..write_string(name)..write_string("\n")
          }
        }
        if names.unnamed_tests > 0 || !names.check_style_tests.is_empty() {
          sb.write_string("  test name warnings:\n")
          if names.unnamed_tests > 0 {
            sb
            ..write_string("    - unnamed tests: ")
            ..write_string(names.unnamed_tests.to_string())
            ..write_string("\n")
          }
          for name in names.check_style_tests {
            sb
            ..write_string("    - check-style: ")
            ..write_string(name)
            ..write_string("\n")
          }
        }
        let doc_info = extract_doc_tests(source, false)
        if doc_info.block_count > 0 {
          doc_info.tests.sort_by((a, b) => a.compare(b))
          doc_info.check_style_tests.sort_by((a, b) => a.compare(b))
          sb.write_string("  doc tests:\n")
          sb
          ..write_string("    code_blocks: ")
          ..write_string(doc_info.block_count.to_string())
          ..write_string("\n")
          sb.write_string("    tests:\n")
          if doc_info.tests.is_empty() {
            sb.write_string("      - (none)\n")
          } else {
            for name in doc_info.tests {
              sb
              ..write_string("      - ")
              ..write_string(name)
              ..write_string("\n")
            }
          }
          if doc_info.unnamed_tests > 0 ||
            !doc_info.check_style_tests.is_empty() {
            sb.write_string("    test name warnings:\n")
            if doc_info.unnamed_tests > 0 {
              sb
              ..write_string("      - unnamed tests: ")
              ..write_string(doc_info.unnamed_tests.to_string())
              ..write_string("\n")
            }
            for name in doc_info.check_style_tests {
              sb
              ..write_string("      - check-style: ")
              ..write_string(name)
              ..write_string("\n")
            }
          }
        }
      }
      Err(err) => {
        sb
        ..write_string("- file: ")
        ..write_string(display_path)
        ..write_string("\n")
        sb
        ..write_string("  package: ")
        ..write_string(package_name)
        ..write_string("\n")
        sb..write_string("  parse_error: ")..write_string(err.to_string())
        sb.write_string("\n")
      }
    }
  }
  sb.write_string("\ndoc_tests:\n")
  if doc_entries.is_empty() {
    sb.write_string("  - (none)\n")
  } else {
    let mut printed = false
    for doc_path in doc_entries {
      let fs_path = join_path(module_root, doc_path)
      let doc_source_result : Result[String, Error] = try? fs.read_string(
        fs_path,
      )
      match doc_source_result {
        Ok(doc_source) => {
          let info = extract_doc_tests(doc_source, true)
          if info.block_count == 0 {
            continue
          }
          printed = true
          sb
          ..write_string("- file: ")
          ..write_string(doc_path)
          ..write_string("\n")
          sb
          ..write_string("  code_blocks: ")
          ..write_string(info.block_count.to_string())
          ..write_string("\n")
          sb.write_string("  tests:\n")
          if info.tests.is_empty() {
            sb.write_string("    - (none)\n")
          } else {
            for name in info.tests {
              sb..write_string("    - ")..write_string(name)..write_string("\n")
            }
          }
          if info.unnamed_tests > 0 || !info.check_style_tests.is_empty() {
            sb.write_string("  test name warnings:\n")
            if info.unnamed_tests > 0 {
              sb
              ..write_string("    - unnamed tests: ")
              ..write_string(info.unnamed_tests.to_string())
              ..write_string("\n")
            }
            for name in info.check_style_tests {
              sb
              ..write_string("    - check-style: ")
              ..write_string(name)
              ..write_string("\n")
            }
          }
        }
        Err(err) => {
          printed = true
          sb
          ..write_string("- file: ")
          ..write_string(doc_path)
          ..write_string("\n")
          sb..write_string("  read_error: ")..write_string(err.to_string())
          sb.write_string("\n")
        }
      }
    }
    if !printed {
      sb.write_string("  - (none)\n")
    }
  }
  println(sb.to_string())
}

///|
fn[FS : @vfs.VFS] default_config_path(fs : FS, module_root : String) -> String? {
  let primary = join_path(module_root, "starlint.json")
  if fs.path_exists(primary) {
    return Some(primary)
  }
  let hidden = join_path(module_root, ".starlint.json")
  if fs.path_exists(hidden) {
    return Some(hidden)
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
let cli_version = "0.6.1"

///|
fn usage_text() -> String {
  let text =
    #| usage:
    #|   starlint [--ai] [--fix] [--rule <id>] [--config <file>] [--by-file|--by-rule] <file1> <file2> ...
    #|   starlint init
    #|   starlint doc
    #|   starlint baseline [--compare <file>]
    #|   starlint analyze [--compare <file>]
    #|   starlint --help | -h
    #|   starlint --version | -v
  text
}

///|
fn parse_meta_option(args : ArrayView[String]) -> String {
  for arg in args {
    if arg == "--help" || arg == "-h" {
      return "help"
    }
    if arg == "--version" || arg == "-v" {
      return "version"
    }
  }
  ""
}

///|
fn parse_compare_option(args : ArrayView[String]) -> String {
  for i in 0..<args.length() {
    if (args[i] == "--compare" || args[i] == "-c") && i + 1 < args.length() {
      return args[i + 1]
    }
  }
  ""
}

///|
fn[FS : @vfs.VFS] analyze_compare_path(
  fs : FS,
  module_root : String,
  compare_arg : String,
) -> String {
  if compare_arg == "" {
    default_analyze_compare_path(fs, module_root)
  } else {
    resolve_config_path(module_root, compare_arg)
  }
}

///|
fn[FS : @vfs.VFS] load_config(
  fs : FS,
  path : String,
) -> @starlint.LintConfig raise {
  let text = fs.read_string(path)
  @starlint.LintConfig::from_json(text)
}

///|
fn[FS : @vfs.VFS] lint_file(
  fs : FS,
  fs_path : String,
  display_path : String,
  package_filenames : Array[String],
  rules : Array[@starlint.Rule],
  config : @starlint.LintConfig,
) -> Array[@starlint.Diagnostic] raise {
  let (impls, source) = read_mbt_file_to_impls(fs, fs_path, display_path)
  let input = @starlint.LintInput::new(
    impls~,
    source~,
    filename=display_path,
    package_filenames~,
  )
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
fn[FS : @vfs.VFS] run_analyze(
  fs : FS,
  module_root : String,
  compare_arg : String,
) -> Unit {
  let compare_path = analyze_compare_path(fs, module_root, compare_arg)
  if fs.path_exists(compare_path) {
    println("== Baseline comparison ==")
    run_baseline(fs, module_root, compare_path)
  } else {
    println("baseline file not found: \{compare_path}")
    println("run `starlint baseline` to create baseline first.")
  }
  let module_info = load_module_info(fs, module_root) catch {
    err => {
      println("failed to load module info: \{err}")
      panic()
    }
  }
  let module_name = get_module_name(module_info)
  let base_rel = get_src_location(module_info)
  let base_fs = if base_rel == "." || base_rel == "" {
    module_root
  } else {
    join_path(module_root, base_rel)
  }
  let file_entries = build_file_entries_from_module(
    fs, module_root, base_fs, base_rel,
  ) catch {
    err => {
      println("failed when finding source files: \{err}")
      panic()
    }
  }
  let doc_entries = get_mbt_md_path_set_from_base(fs, module_root, ".") catch {
    err => {
      println("failed when finding doc files: \{err}")
      panic()
    }
  }
  doc_entries.sort_by((a, b) => a.compare(b))
  println("")
  println("== AI analysis metadata ==")
  print_ai_metadata(fs, file_entries, doc_entries, module_name, module_root)
}

///|
fn[FS : @vfs.VFS] apply_fixes_to_file(
  fs : FS,
  fs_path : String,
  display_path : String,
  diagnostics : Array[@starlint.Diagnostic],
) -> Int raise {
  let fixes = collect_fixes(diagnostics, display_path)
  if fixes.is_empty() {
    return 0
  }
  let source = fs.read_string(fs_path)
  let (new_source, applied) = apply_fixes_to_source(source, fixes)
  if applied > 0 && new_source != source {
    let (_, reports) = @starlint.parse_string_for_lint(
      new_source,
      name=display_path,
    )
    if reports.length() > 0 {
      return 0
    }
    fs.write_string(fs_path, new_source)
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
fn[FS : @vfs.VFS] resolve_module_root(
  fs : FS,
  start_dir : String,
) -> String raise Error {
  match find_module_root(fs, start_dir) {
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
fn[FS : @vfs.VFS] build_file_entries_from_module(
  fs : FS,
  module_root : String,
  base_fs : String,
  base_rel : String,
) -> Array[(String, String)] raise Error {
  let rel_paths = get_mbt_path_set_from_base(fs, base_fs, base_rel)
  let entries = []
  for rel_path in rel_paths {
    let fs_path = join_path(module_root, rel_path)
    entries.push((fs_path, rel_path))
  } else {
    entries
  }
}

///|
fn[FS : @vfs.VFS] run_with_start_dir(
  fs : FS,
  argv : Array[String],
  start_dir : String,
) -> Unit {
  match parse_meta_option(argv[:]) {
    "help" => {
      println(usage_text())
      return
    }
    "version" => {
      println("starlint \{cli_version}")
      return
    }
    _ => ()
  }
  if argv.length() > 0 && !argv[0].has_prefix("-") {
    let cmd = argv[0]
    let rules = @lint.rules()
    if cmd == "doc" {
      print_rules_doc(rules)
      return
    }
    if cmd == "init" {
      let module_root = resolve_module_root(fs, start_dir) catch {
        err => {
          println("failed to find module root: \{err}")
          panic()
        }
      }
      run_init(fs, rules, module_root)
      return
    }
    if cmd == "baseline" {
      let module_root = resolve_module_root(fs, start_dir) catch {
        err => {
          println("failed to find module root: \{err}")
          panic()
        }
      }
      let compare = parse_compare_option(argv[1:])
      run_baseline(fs, module_root, compare)
      return
    }
    if cmd == "analyze" {
      let module_root = resolve_module_root(fs, start_dir) catch {
        err => {
          println("failed to find module root: \{err}")
          panic()
        }
      }
      let compare = parse_compare_option(argv[1:])
      run_analyze(fs, module_root, compare)
      return
    }
  }
  let apply_fix = @ref.new(false)
  let config_path = @ref.new("")
  let rule_filter = @ref.new("")
  let ai_mode = @ref.new(false)
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
    (
      "--rule",
      "-r",
      @ArgParser.Spec::Set_string(rule_filter),
      "filter by rule id",
    ),
    ("--ai", "", @ArgParser.Spec::Set(ai_mode), "output AI review metadata"),
    ("--by-file", "", @ArgParser.Spec::Set(by_file), "group by file (default)"),
    ("--by-rule", "", @ArgParser.Spec::Set(by_rule), "group by rule"),
  ]
  let filenames = []
  @ArgParser.parse(
    spec,
    filename => filenames.push(filename),
    usage_text(),
    argv,
  ) catch {
    @ArgParser.ErrorMsg(msg) => {
      println(msg)
      return
    }
    err => {
      println(err)
      panic()
    }
  }
  let module_root = resolve_module_root(fs, start_dir) catch {
    err => {
      println("failed to find module root: \{err}")
      panic()
    }
  }
  let module_info = load_module_info(fs, module_root) catch {
    err => {
      println("failed to load module info: \{err}")
      panic()
    }
  }
  let module_name = get_module_name(module_info)
  let base_rel = get_src_location(module_info)
  let base_fs = if base_rel == "." || base_rel == "" {
    module_root
  } else {
    join_path(module_root, base_rel)
  }
  let file_entries = if filenames.length() == 0 {
    build_file_entries_from_module(fs, module_root, base_fs, base_rel) catch {
      err => {
        println("failed when finding source files: \{err}")
        panic()
      }
    }
  } else {
    build_file_entries_from_args(filenames, start_dir, module_root)
  }
  let doc_entries = get_mbt_md_path_set_from_base(fs, module_root, ".") catch {
    err => {
      println("failed when finding doc files: \{err}")
      panic()
    }
  }
  doc_entries.sort_by((a, b) => a.compare(b))
  if ai_mode.val {
    print_ai_metadata(fs, file_entries, doc_entries, module_name, module_root)
    return
  }
  let rules = @lint.rules()
  let config = match resolve_config_path(module_root, config_path.val) {
    "" =>
      match default_config_path(fs, module_root) {
        Some(path) =>
          load_config(fs, path) catch {
            err => {
              println("failed to load config: \{err}")
              panic()
            }
          }
        None => @starlint.LintConfig::recommended()
      }
    path =>
      load_config(fs, path) catch {
        err => {
          println("failed to load config: \{err}")
          panic()
        }
      }
  }
  let use_by_rule = if by_file.val { false } else { by_rule.val }
  let package_filenames = []
  for entry in file_entries {
    let (_, display_path) = entry
    package_filenames.push(display_path)
  }
  let diagnostics = []
  for entry in file_entries {
    let (fs_path, display_path) = entry
    let file_config = config.for_file(display_path)
    if file_config.is_ignored(display_path) {
      continue
    }
    let mut file_diagnostics = lint_file(
      fs, fs_path, display_path, package_filenames, rules, file_config,
    ) catch {
      err => {
        println(err)
        panic()
      }
    }
    if rule_filter.val != "" {
      file_diagnostics = file_diagnostics.filter(diag => diag.rule_id ==
        rule_filter.val)
    }
    if apply_fix.val {
      let applied = apply_fixes_to_file(
        fs, fs_path, display_path, file_diagnostics,
      ) catch {
        err => {
          println(err)
          panic()
        }
      }
      if applied > 0 {
        let refreshed_config = config.for_file(display_path)
        file_diagnostics = lint_file(
          fs, fs_path, display_path, package_filenames, rules, refreshed_config,
        ) catch {
          err => {
            println(err)
            panic()
          }
        }
        if rule_filter.val != "" {
          file_diagnostics = file_diagnostics.filter(diag => diag.rule_id ==
            rule_filter.val)
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
  let fs = @vfs.WasiVFS::new()
  run_with_start_dir(fs, args, resolve_start_dir(start_dir))
}

///|
fn main {
  let argv = @sys.get_cli_args()[1:].to_array()
  run(argv)
}
