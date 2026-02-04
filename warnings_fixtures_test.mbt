///|
struct WarningFixture {
  name : String
  input : String
  expected : String
}

///|
fn test_lint_for_warning_fixtures(
  source : String,
) -> Array[@moonlint.Diagnostic] raise {
  let (impls, reports) = @parser.parse_string(source, name="<warning fixture>")
  if reports.length() > 0 {
    fail(reports.to_json().stringify(indent=2))
  }
  let input = @moonlint.LintInput::new(
    impls~,
    source~,
    filename="<warning fixture>",
  )
  let config = @moonlint.LintConfig::enable_categories(["fp"])
  @moonlint.lint_with_config(input, @lint.rules(), config)
}

///|
test "warning fixtures" {
  let fixtures : Array[WarningFixture] = [
    WarningFixture::{
      name: "match_guard_to_if_basic",
      input: (
        #|fn main {
        #|  match x {
        #|    _ if is_small(x) => handle_small()
        #|    _ if is_large(x) => handle_large()
        #|    _ => handle_other()
        #|  }
        #|}
      ),
      expected: "[\"match_guard_to_if\"]",
    },
    WarningFixture::{
      name: "match_guard_to_if_non_wildcard",
      input: (
        #|fn main {
        #|  match x {
        #|    Some(v) if v > 0 => handle(v)
        #|    _ => ()
        #|  }
        #|}
      ),
      expected: "[]",
    },
    WarningFixture::{
      name: "prefer_guard_chain_nested",
      input: (
        #|fn main {
        #|  match a {
        #|    A(x) => match b {
        #|      B(y) => match c {
        #|        C(z) => work(z)
        #|        _ => ()
        #|      }
        #|      _ => ()
        #|    }
        #|    _ => ()
        #|  }
        #|}
      ),
      expected: "[\"prefer_guard_chain\"]",
    },
    WarningFixture::{
      name: "prefer_guard_chain_with_guard",
      input: (
        #|fn main {
        #|  match a {
        #|    A(x) if x > 0 => match b {
        #|      B(y) => ()
        #|      _ => ()
        #|    }
        #|    _ => ()
        #|  }
        #|}
      ),
      expected: "[]",
    },
  ]
  for fixture in fixtures {
    let _ = fixture.name
    let diagnostics = test_lint_for_warning_fixtures(fixture.input)
    let summary = diagnostics.map(diag => diag.rule_id)
    inspect(summary, content=fixture.expected)
  }
}
