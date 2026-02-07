///|
pub(all) struct BaselineComparison {
  added_apis : Array[String]
  removed_apis : Array[String]
  loc_delta : Int
  complexity_regressions : Array[ComplexityRegression]
  diagnostic_changes : Map[String, Int]
  summary_delta : SummaryDelta
}

///|
pub(all) struct ComplexityRegression {
  file : String
  function_name : String
  old_complexity : Int
  new_complexity : Int
}

///|
pub(all) struct SummaryDelta {
  total_files : Int
  total_loc : Int
  total_packages : Int
  total_pub_apis : Int
  total_tests : Int
  total_diagnostics : Int
  max_complexity : Int
}

///|
pub fn compare_baselines(old : Baseline, new_ : Baseline) -> BaselineComparison {
  // Collect all pub API names
  let old_apis : Map[String, Bool] = Map::new()
  for _, pkg in old.packages {
    for name in pkg.pub_api_names {
      old_apis.set(name, true)
    }
  }
  let new_apis : Map[String, Bool] = Map::new()
  for _, pkg in new_.packages {
    for name in pkg.pub_api_names {
      new_apis.set(name, true)
    }
  }
  let added_apis = []
  for name, _ in new_apis {
    if old_apis.get(name) is None {
      added_apis.push(name)
    }
  }
  added_apis.sort_by((a, b) => a.compare(b))
  let removed_apis = []
  for name, _ in old_apis {
    if new_apis.get(name) is None {
      removed_apis.push(name)
    }
  }
  removed_apis.sort_by((a, b) => a.compare(b))
  // LOC delta
  let loc_delta = new_.summary.total_loc - old.summary.total_loc
  // Complexity regressions
  let complexity_regressions = []
  for file_name, new_file in new_.files {
    match old.files.get(file_name) {
      Some(old_file) => {
        let old_fns : Map[String, Int] = Map::new()
        for fc in old_file.functions {
          old_fns.set(fc.name, fc.complexity)
        }
        for fc in new_file.functions {
          match old_fns.get(fc.name) {
            Some(old_c) =>
              if fc.complexity > old_c {
                complexity_regressions.push(ComplexityRegression::{
                  file: file_name,
                  function_name: fc.name,
                  old_complexity: old_c,
                  new_complexity: fc.complexity,
                })
              }
            None => ()
          }
        }
      }
      None => ()
    }
  }
  complexity_regressions.sort_by((a, b) => {
    let cmp = a.file.compare(b.file)
    if cmp != 0 {
      cmp
    } else {
      a.function_name.compare(b.function_name)
    }
  })
  // Diagnostic changes
  let diagnostic_changes : Map[String, Int] = Map::new()
  for rule, new_count in new_.diagnostics.by_rule {
    let old_count = match old.diagnostics.by_rule.get(rule) {
      Some(c) => c
      None => 0
    }
    let delta = new_count - old_count
    if delta != 0 {
      diagnostic_changes.set(rule, delta)
    }
  }
  for rule, old_count in old.diagnostics.by_rule {
    if new_.diagnostics.by_rule.get(rule) is None {
      diagnostic_changes.set(rule, -old_count)
    }
  }
  // Summary delta
  let summary_delta = SummaryDelta::{
    total_files: new_.summary.total_files - old.summary.total_files,
    total_loc: loc_delta,
    total_packages: new_.summary.total_packages - old.summary.total_packages,
    total_pub_apis: new_.summary.total_pub_apis - old.summary.total_pub_apis,
    total_tests: new_.summary.total_tests - old.summary.total_tests,
    total_diagnostics: new_.summary.total_diagnostics -
    old.summary.total_diagnostics,
    max_complexity: new_.summary.max_complexity - old.summary.max_complexity,
  }
  BaselineComparison::{
    added_apis,
    removed_apis,
    loc_delta,
    complexity_regressions,
    diagnostic_changes,
    summary_delta,
  }
}

///|
fn format_delta(value : Int) -> String {
  if value > 0 {
    "+\{value}"
  } else {
    value.to_string()
  }
}

///|
pub fn format_comparison(comp : BaselineComparison) -> String {
  let sb = StringBuilder::new()
  sb.write_string("Baseline Comparison\n")
  sb.write_string("===================\n\n")
  // Summary
  sb.write_string("Summary:\n")
  sb.write_string(
    "  files:       \{format_delta(comp.summary_delta.total_files)}\n",
  )
  sb.write_string(
    "  loc:         \{format_delta(comp.summary_delta.total_loc)}\n",
  )
  sb.write_string(
    "  packages:    \{format_delta(comp.summary_delta.total_packages)}\n",
  )
  sb.write_string(
    "  pub APIs:    \{format_delta(comp.summary_delta.total_pub_apis)}\n",
  )
  sb.write_string(
    "  tests:       \{format_delta(comp.summary_delta.total_tests)}\n",
  )
  sb.write_string(
    "  diagnostics: \{format_delta(comp.summary_delta.total_diagnostics)}\n",
  )
  sb.write_string(
    "  max complexity: \{format_delta(comp.summary_delta.max_complexity)}\n",
  )
  // API changes
  if !comp.added_apis.is_empty() {
    sb.write_string("\nAdded APIs:\n")
    for name in comp.added_apis {
      sb.write_string("  + \{name}\n")
    }
  }
  if !comp.removed_apis.is_empty() {
    sb.write_string("\nRemoved APIs:\n")
    for name in comp.removed_apis {
      sb.write_string("  - \{name}\n")
    }
  }
  // Complexity regressions
  if !comp.complexity_regressions.is_empty() {
    sb.write_string("\nComplexity Regressions:\n")
    for reg in comp.complexity_regressions {
      sb.write_string(
        "  \{reg.file}: \{reg.function_name} \{reg.old_complexity} -> \{reg.new_complexity}\n",
      )
    }
  }
  // Diagnostic changes
  let has_diag_changes = {
    let mut found = false
    for _, _ in comp.diagnostic_changes {
      found = true
    }
    found
  }
  if has_diag_changes {
    sb.write_string("\nDiagnostic Changes:\n")
    for rule, delta in comp.diagnostic_changes {
      sb.write_string("  \{rule}: \{format_delta(delta)}\n")
    }
  }
  sb.to_string()
}
