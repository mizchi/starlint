///|
fn read_mbt_file_to_impls(filename : String) -> (@syntax.Impls, String) raise {
  let source = @fs.read_file_to_string(filename)
  let (impls, reports) = @parser.parse_string(
    source,
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
fn lint_file(
  filename : String,
  rules : Array[@moonlint.Rule],
) -> Array[@moonlint.Diagnostic] raise {
  let (impls, source) = read_mbt_file_to_impls(filename)
  let input = @moonlint.LintInput::new(impls~, source~, filename~)
  return @moonlint.lint(input, rules)
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
  let spec : Array[(String, String, @ArgParser.Spec, String)] = [
    ("--fix", "-f", @ArgParser.Spec::Set(apply_fix), "apply autofixes"),
  ]
  let filenames = []
  let usage =
    #| usage: 
    #|   moonlint.exe [--fix] <file1> <file2> ...
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
  // make output more human-friendly
  println(" ")
  for filename in filenames {
    let mut diagnostics = lint_file(filename, rules) catch {
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
        diagnostics = lint_file(filename, rules) catch {
          err => {
            println(err)
            panic()
          }
        }
        println("Applied \{applied} fixes in \{filename}")
      }
    }
    for diag in diagnostics {
      println(@moonlint.format_diagnostic(diag))
    }
  }
}
