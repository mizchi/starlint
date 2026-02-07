///|
pub(all) struct Baseline {
  version : String
  packages : Map[String, PackageBaseline]
  files : Map[String, FileBaseline]
  diagnostics : DiagnosticsSummary
  summary : BaselineSummary
}

///|
pub(all) struct PackageBaseline {
  pub_fn_count : Int
  pub_type_count : Int
  pub_api_names : Array[String]
  test_count : Int
  loc : Int
}

///|
pub(all) struct FileBaseline {
  package_name : String
  loc : Int
  functions : Array[FunctionComplexity]
  complexity_avg : Double
  complexity_max : Int
}

///|
pub(all) struct DiagnosticsSummary {
  total : Int
  by_rule : Map[String, Int]
}

///|
pub(all) struct BaselineSummary {
  total_files : Int
  total_loc : Int
  total_packages : Int
  total_pub_apis : Int
  total_tests : Int
  total_diagnostics : Int
  avg_complexity : Double
  max_complexity : Int
}

///|
fn escape_json_string(s : String) -> String {
  let sb = StringBuilder::new()
  for i in 0..<s.length() {
    let c = s[i]
    if c == ('"' : UInt16) {
      sb.write_string("\\\"")
    } else if c == ('\\' : UInt16) {
      sb.write_string("\\\\")
    } else if c == ('\n' : UInt16) {
      sb.write_string("\\n")
    } else if c == ('\r' : UInt16) {
      sb.write_string("\\r")
    } else if c == ('\t' : UInt16) {
      sb.write_string("\\t")
    } else {
      sb.write_char(Int::unsafe_to_char(c.to_int()))
    }
  }
  sb.to_string()
}

///|
fn write_json_string_array(
  sb : StringBuilder,
  items : Array[String],
  indent : String,
) -> Unit {
  if items.is_empty() {
    sb.write_string("[]")
    return
  }
  sb.write_string("[\n")
  let mut first = true
  for item in items {
    if first {
      first = false
    } else {
      sb.write_string(",\n")
    }
    sb.write_string(indent)
    sb.write_string("  \"")
    sb.write_string(escape_json_string(item))
    sb.write_string("\"")
  }
  sb.write_string("\n")
  sb.write_string(indent)
  sb.write_string("]")
}

///|
fn write_function_complexity_array(
  sb : StringBuilder,
  items : Array[FunctionComplexity],
  indent : String,
) -> Unit {
  if items.is_empty() {
    sb.write_string("[]")
    return
  }
  sb.write_string("[\n")
  let mut first = true
  for item in items {
    if first {
      first = false
    } else {
      sb.write_string(",\n")
    }
    sb.write_string(indent)
    sb.write_string("  { \"name\": \"")
    sb.write_string(escape_json_string(item.name))
    sb.write_string("\", \"complexity\": ")
    sb.write_string(item.complexity.to_string())
    sb.write_string(" }")
  }
  sb.write_string("\n")
  sb.write_string(indent)
  sb.write_string("]")
}

///|
pub fn format_double(d : Double) -> String {
  let rounded = (d * 10.0 + 0.5).to_int()
  let integer_part = rounded / 10
  let decimal_part = rounded % 10
  "\{integer_part}.\{decimal_part}"
}

///|
pub fn Baseline::to_json(self : Baseline) -> String {
  let sb = StringBuilder::new()
  sb.write_string("{\n")
  sb.write_string("  \"version\": \"")
  sb.write_string(escape_json_string(self.version))
  sb.write_string("\",\n")
  // packages
  sb.write_string("  \"packages\": {\n")
  let mut pkg_first = true
  for name, pkg in self.packages {
    if pkg_first {
      pkg_first = false
    } else {
      sb.write_string(",\n")
    }
    sb.write_string("    \"")
    sb.write_string(escape_json_string(name))
    sb.write_string("\": {\n")
    sb.write_string("      \"pub_fn_count\": ")
    sb.write_string(pkg.pub_fn_count.to_string())
    sb.write_string(",\n")
    sb.write_string("      \"pub_type_count\": ")
    sb.write_string(pkg.pub_type_count.to_string())
    sb.write_string(",\n")
    sb.write_string("      \"pub_api_names\": ")
    write_json_string_array(sb, pkg.pub_api_names, "      ")
    sb.write_string(",\n")
    sb.write_string("      \"test_count\": ")
    sb.write_string(pkg.test_count.to_string())
    sb.write_string(",\n")
    sb.write_string("      \"loc\": ")
    sb.write_string(pkg.loc.to_string())
    sb.write_string("\n")
    sb.write_string("    }")
  }
  sb.write_string("\n  },\n")
  // files
  sb.write_string("  \"files\": {\n")
  let mut file_first = true
  for name, file in self.files {
    if file_first {
      file_first = false
    } else {
      sb.write_string(",\n")
    }
    sb.write_string("    \"")
    sb.write_string(escape_json_string(name))
    sb.write_string("\": {\n")
    sb.write_string("      \"package_name\": \"")
    sb.write_string(escape_json_string(file.package_name))
    sb.write_string("\",\n")
    sb.write_string("      \"loc\": ")
    sb.write_string(file.loc.to_string())
    sb.write_string(",\n")
    sb.write_string("      \"functions\": ")
    write_function_complexity_array(sb, file.functions, "      ")
    sb.write_string(",\n")
    sb.write_string("      \"complexity_avg\": ")
    sb.write_string(format_double(file.complexity_avg))
    sb.write_string(",\n")
    sb.write_string("      \"complexity_max\": ")
    sb.write_string(file.complexity_max.to_string())
    sb.write_string("\n")
    sb.write_string("    }")
  }
  sb.write_string("\n  },\n")
  // diagnostics
  sb.write_string("  \"diagnostics\": {\n")
  sb.write_string("    \"total\": ")
  sb.write_string(self.diagnostics.total.to_string())
  sb.write_string(",\n")
  sb.write_string("    \"by_rule\": {\n")
  let mut rule_first = true
  for name, count in self.diagnostics.by_rule {
    if rule_first {
      rule_first = false
    } else {
      sb.write_string(",\n")
    }
    sb.write_string("      \"")
    sb.write_string(escape_json_string(name))
    sb.write_string("\": ")
    sb.write_string(count.to_string())
  }
  sb.write_string("\n    }\n")
  sb.write_string("  },\n")
  // summary
  sb.write_string("  \"summary\": {\n")
  sb.write_string("    \"total_files\": ")
  sb.write_string(self.summary.total_files.to_string())
  sb.write_string(",\n")
  sb.write_string("    \"total_loc\": ")
  sb.write_string(self.summary.total_loc.to_string())
  sb.write_string(",\n")
  sb.write_string("    \"total_packages\": ")
  sb.write_string(self.summary.total_packages.to_string())
  sb.write_string(",\n")
  sb.write_string("    \"total_pub_apis\": ")
  sb.write_string(self.summary.total_pub_apis.to_string())
  sb.write_string(",\n")
  sb.write_string("    \"total_tests\": ")
  sb.write_string(self.summary.total_tests.to_string())
  sb.write_string(",\n")
  sb.write_string("    \"total_diagnostics\": ")
  sb.write_string(self.summary.total_diagnostics.to_string())
  sb.write_string(",\n")
  sb.write_string("    \"avg_complexity\": ")
  sb.write_string(format_double(self.summary.avg_complexity))
  sb.write_string(",\n")
  sb.write_string("    \"max_complexity\": ")
  sb.write_string(self.summary.max_complexity.to_string())
  sb.write_string("\n")
  sb.write_string("  }\n")
  sb.write_string("}\n")
  sb.to_string()
}

///|
pub fn Baseline::from_json(text : String) -> Baseline raise {
  let json = @json.parse(text)
  match json {
    Object(obj) => {
      let version = match obj.get("version") {
        Some(String(v)) => v
        _ => "1"
      }
      let packages = Map::new()
      match obj.get("packages") {
        Some(Object(pkg_obj)) =>
          for name, value in pkg_obj {
            match value {
              Object(p) => {
                let pub_fn_count = match p.get("pub_fn_count") {
                  Some(Number(n, ..)) => n.to_int()
                  _ => 0
                }
                let pub_type_count = match p.get("pub_type_count") {
                  Some(Number(n, ..)) => n.to_int()
                  _ => 0
                }
                let pub_api_names = match p.get("pub_api_names") {
                  Some(Array(items)) => {
                    let names = []
                    for item in items {
                      match item {
                        String(s) => names.push(s)
                        _ => ()
                      }
                    }
                    names
                  }
                  _ => []
                }
                let test_count = match p.get("test_count") {
                  Some(Number(n, ..)) => n.to_int()
                  _ => 0
                }
                let loc = match p.get("loc") {
                  Some(Number(n, ..)) => n.to_int()
                  _ => 0
                }
                packages.set(name, PackageBaseline::{
                  pub_fn_count,
                  pub_type_count,
                  pub_api_names,
                  test_count,
                  loc,
                })
              }
              _ => ()
            }
          }
        _ => ()
      }
      let files = Map::new()
      match obj.get("files") {
        Some(Object(file_obj)) =>
          for name, value in file_obj {
            match value {
              Object(f) => {
                let package_name = match f.get("package_name") {
                  Some(String(s)) => s
                  _ => ""
                }
                let loc = match f.get("loc") {
                  Some(Number(n, ..)) => n.to_int()
                  _ => 0
                }
                let functions = match f.get("functions") {
                  Some(Array(items)) => {
                    let fns = []
                    for item in items {
                      match item {
                        Object(fn_obj) => {
                          let fn_name = match fn_obj.get("name") {
                            Some(String(s)) => s
                            _ => ""
                          }
                          let complexity = match fn_obj.get("complexity") {
                            Some(Number(n, ..)) => n.to_int()
                            _ => 1
                          }
                          fns.push(FunctionComplexity::{
                            name: fn_name,
                            complexity,
                          })
                        }
                        _ => ()
                      }
                    }
                    fns
                  }
                  _ => []
                }
                let complexity_avg = match f.get("complexity_avg") {
                  Some(Number(n, ..)) => n
                  _ => 0.0
                }
                let complexity_max = match f.get("complexity_max") {
                  Some(Number(n, ..)) => n.to_int()
                  _ => 0
                }
                files.set(name, FileBaseline::{
                  package_name,
                  loc,
                  functions,
                  complexity_avg,
                  complexity_max,
                })
              }
              _ => ()
            }
          }
        _ => ()
      }
      let diagnostics = match obj.get("diagnostics") {
        Some(Object(d)) => {
          let total = match d.get("total") {
            Some(Number(n, ..)) => n.to_int()
            _ => 0
          }
          let by_rule = Map::new()
          match d.get("by_rule") {
            Some(Object(rule_obj)) =>
              for rule_name, count in rule_obj {
                match count {
                  Number(n, ..) => by_rule.set(rule_name, n.to_int())
                  _ => ()
                }
              }
            _ => ()
          }
          DiagnosticsSummary::{ total, by_rule }
        }
        _ => DiagnosticsSummary::{ total: 0, by_rule: Map::new() }
      }
      let summary = match obj.get("summary") {
        Some(Object(s)) => {
          let get_int = fn(key : String) -> Int {
            match s.get(key) {
              Some(Number(n, ..)) => n.to_int()
              _ => 0
            }
          }
          let get_double = fn(key : String) -> Double {
            match s.get(key) {
              Some(Number(n, ..)) => n
              _ => 0.0
            }
          }
          BaselineSummary::{
            total_files: get_int("total_files"),
            total_loc: get_int("total_loc"),
            total_packages: get_int("total_packages"),
            total_pub_apis: get_int("total_pub_apis"),
            total_tests: get_int("total_tests"),
            total_diagnostics: get_int("total_diagnostics"),
            avg_complexity: get_double("avg_complexity"),
            max_complexity: get_int("max_complexity"),
          }
        }
        _ =>
          BaselineSummary::{
            total_files: 0,
            total_loc: 0,
            total_packages: 0,
            total_pub_apis: 0,
            total_tests: 0,
            total_diagnostics: 0,
            avg_complexity: 0.0,
            max_complexity: 0,
          }
      }
      Baseline::{ version, packages, files, diagnostics, summary }
    }
    _ => fail("Invalid JSON: expected object")
  }
}
