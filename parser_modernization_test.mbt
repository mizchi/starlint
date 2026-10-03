///|
test "legacy call diagnostic retains Unicode and newline offsets" {
  let source =
    #|// 日本語 😀
    #|fn main {
    #|  let text = "try? f!()"
    #|  f!(1)
    #|}
  let diagnostics = test_lint(source).filter(d => {
    d.rule_id == "legacy_call_syntax"
  })
  inspect(diagnostics.length(), content="1")
  let diagnostic = diagnostics[0]
  inspect(diagnostic.loc.start.lnum, content="4")
  inspect(diagnostic.loc.start.cnum - diagnostic.loc.start.bol, content="2")
  inspect(
    source[diagnostic.loc.start.cnum:diagnostic.loc.end.cnum].to_owned(),
    content="f!(1)",
  )
}

///|
test "obsolete loop grammar reports a parse error" {
  let (_, reports) = parse_string_for_lint(
    "fn main { loop 0 { n => continue n + 1 } }",
  )
  inspect(reports.is_empty(), content="false")
}

///|
test "modern loops retain complexity traversal" {
  let source =
    #|fn count(xs : Array[Int]) -> Int {
    #|  let mut total = 0
    #|  for x in xs { if x > 0 { total += x } }
    #|  while total > 5 { total -= 1 }
    #|  for i = 0; i < 2; i = i + 1 { total += i }
    #|  total
    #|}
  let (impls, reports) = parse_string_for_lint(source)
  inspect(reports.is_empty(), content="true")
  let functions = compute_file_complexity(impls, source)
  inspect(functions.length(), content="1")
  inspect(functions[0].complexity, content="5")
}

///|
test "modern loop visitors keep unicode and string-builder diagnostics" {
  let source =
    #|fn main {
    #|  let mut text = ""
    #|  for i in [0] { text += "x"; ignore("abc"[i]) }
    #|  while flag { text += "x"; ignore("abc"[0]) }
    #|  for i = 0; i < 2; i = i + 1 { text += "x"; ignore("abc"[i]) }
    #|}
  let diagnostics = test_lint(source)
  inspect(
    diagnostics
    .filter(d => d.rule_id == "prefer_unicode_safe_iteration")
    .length(),
    content="3",
  )
  inspect(
    diagnostics
    .filter(d => d.rule_id == "prefer_string_builder_for_concat")
    .length(),
    content="3",
  )
}
