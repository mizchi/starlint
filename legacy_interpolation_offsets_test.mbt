///|
test "legacy calls after supplementary Unicode inside interpolation" {
  let source =
    #|fn main { println("value: \{("😀", f!())}") }
  let diagnostics = test_lint(source).filter(d => {
    d.rule_id == "legacy_call_syntax"
  })
  assert_eq(diagnostics.length(), 1)
  let diag = diagnostics[0]
  assert_eq(source[diag.loc.start.cnum:diag.loc.end.cnum].to_owned(), "f!()")
}

///|
test "legacy calls inside ASCII interpolation are traversed" {
  let source =
    #|fn main { println("value: \{(1, f!())}") }
  let diagnostics = test_lint(source).filter(d => {
    d.rule_id == "legacy_call_syntax"
  })
  assert_eq(diagnostics.length(), 1)
}
