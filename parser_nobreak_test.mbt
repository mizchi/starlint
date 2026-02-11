///|
test "parse nobreak loop expression" {
  let source =
    #|fn lint_with_config() -> Array[Int] {
    #|  let diagnostics = Array::new(capacity=0)
    #|  let rules = [1]
    #|  for rule in rules {
    #|    diagnostics.push(rule)
    #|  } nobreak {
    #|    diagnostics
    #|  }
    #|}
  let (_, reports) = parse_string_for_lint(
    source,
    name="<nobreak>",
    parser=MoonYacc,
  )
  if reports.length() > 0 {
    fail(reports.to_json().stringify(indent=2))
  }
}
