///|
test "legacy effect calls do not receive unsafe style rewrites" {
  let cases = [
    ("fn main { f!(g(x)) }", "prefer_pipeline"),
    ("fn main { f(g!(x)) }", "prefer_pipeline"),
    ("fn main { f(g(h(x)?)) }", "prefer_pipeline"),
    ("fn main { let apply = x => f?(x) }", "prefer_eta_reduce"),
    (
      "fn main { match opt { Some(v) if pred(v) => Some?(v); None => None } }", "prefer_option_filter",
    ),
    ("fn main { let x = f!(1); let x = g(x); x }", "prefer_pipeline_rebind"),
  ]
  for (source, rule_id) in cases {
    let diagnostics = test_lint(source)
    assert_true(diagnostics.any(diag => diag.rule_id == "legacy_call_syntax"))
    assert_false(diagnostics.any(diag => diag.rule_id == rule_id))
  }
}

///|
test "legacy call lint does not mistake nested strings or comments for markers" {
  let source =
    #|fn main {
    #|  f("g!(x)")
    #|  f("g?(x)")
    #|  f(1) // g!(x)
    #|  (f!(g?(1)))
    #|}
  let diagnostics = test_lint(source)
  let legacy = diagnostics.filter(diag => diag.rule_id == "legacy_call_syntax")
  assert_eq(legacy.length(), 2)
}

///|
test "legacy postfix question after whitespace and comments" {
  let source =
    #|fn main {
    #|  f() ?
    #|  g() // question ? inside comment
    #|  ?
    #|}
  let diagnostics = test_lint(source).filter(d => {
    d.rule_id == "legacy_call_syntax"
  })
  assert_eq(diagnostics.length(), 2)
  let diag = diagnostics[1]
  assert_eq(diag.loc.end.lnum, 4)
  assert_eq(
    source[diag.loc.start.cnum:diag.loc.end.cnum].to_owned(),
    "g() // question ? inside comment\n  ?",
  )
}
