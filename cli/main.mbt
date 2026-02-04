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
  let apply_fix = @ref.new(false)
  let config_path = @ref.new("")
  let spec : Array[(String, String, @ArgParser.Spec, String)] = [
    ("--fix", "-f", @ArgParser.Spec::Set(apply_fix), "apply autofixes"),
    (
      "--config",
      "-c",
      @ArgParser.Spec::Set_string(config_path),
      "config file path",
    ),
  ]
  let filenames = []
  let usage =
    #| usage: 
    #|   moonlint.exe [--fix] [--config <file>] <file1> <file2> ...
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
  // make output more human-friendly
  println(" ")
  for filename in filenames {
    let mut diagnostics = lint_file(filename, rules, config) catch {
      err => {
        println(err)
        panic()
      }
    }
    if apply_fix.val {
      let applied = apply_fixes_to_file(filename, diagnostics) catch {
        err => {
          println(err)
          panic()
        }
      }
      if applied > 0 {
        diagnostics = lint_file(filename, rules, config) catch {
          err => {
            println(err)
            panic()
          }
        }
        println("Applied \{applied} fixes in \{filename}")
      }
    }
    for diag in diagnostics {
      diag |> @moonlint.format_diagnostic |> println
    }
  }
}
