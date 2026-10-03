///|
fn legacy_test_loc(start : Int, end : Int) -> @basic.Location {
  let pos : @basic.Position = { fname: "test", lnum: 1, bol: 0, cnum: start, }
  { start: pos, end: { ..pos, cnum: end, }, }
}

///|
fn legacy_test_call(callee_end : Int, end : Int) -> @syntax.Expr {
  @syntax.Apply(
    func=@syntax.Unit(faked=false, loc=legacy_test_loc(0, callee_end)),
    args=@list.List::from_array([]),
    loc=legacy_test_loc(0, end),
  )
}

///|
test "legacy markers use AST boundaries and preserve postfix ranges" {
  let source = "f!(1)"
  let call = legacy_test_call(1, source.length())
  assert_true(legacy_call_marker(source, call) is Some((1, false, _)))
  let source = "f?(1)"
  assert_true(legacy_call_marker(source, call) is Some((1, true, _)))
  let source = "f(1)?"
  let call = legacy_test_call(1, source.length() - 1)
  assert_true(legacy_call_marker(source, call) is Some((4, true, _)))
  if legacy_call_marker(source, call) is Some((_, _, loc)) {
    assert_eq(loc.end.cnum, 5)
  } else {
    fail("missing postfix call marker")
  }
  let grouped = @syntax.Group(expr=call, group=Paren, loc=legacy_test_loc(0, 5))
  assert_true(legacy_call_marker(source, grouped) is None)
}

///|
test "legacy markers ignore argument strings and comments" {
  for
    source in [
      "f(\"!(\")", "f(\"?(\")", "f(g!(1))", "f /* !( */ (1)", "f // ?(\n(1)",
    ] {
    assert_true(
      legacy_call_marker(source, legacy_test_call(1, source.length())) is None,
    )
  }
  let source = "f /* nested /* ?( */ !( */ ! (1)"
  assert_true(
    legacy_call_marker(source, legacy_test_call(1, source.length()))
    is Some((_, false, _)),
  )
}

///|
test "try question checks original source rather than normalized kind" {
  let expr = @syntax.TryOperator(
    body=@syntax.Unit(faked=false, loc=legacy_test_loc(5, 7)),
    kind=Exclamation,
    try_loc=legacy_test_loc(0, 4),
    loc=legacy_test_loc(0, 7),
  )
  assert_true(match_try_question(expr, source="try? ()") is Some(_))
  assert_true(match_try_question(expr, source="try! ()") is None)
  assert_true(match_try_question(expr, source="") is None)
}

///|
test "postfix question marks after trivia retain full ranges" {
  let source = "f(1) // ? in comment\n  ?"
  let call = legacy_test_call(1, 4)
  if legacy_call_marker(source, call) is Some((marker, true, loc)) {
    assert_eq(marker, source.length() - 1)
    assert_eq(loc.end.cnum, source.length())
    assert_eq(loc.end.lnum, 2)
    assert_eq(loc.end.cnum - loc.end.bol, 3)
  } else {
    fail("missing postfix marker after comment")
  }
  assert_true(legacy_call_marker("f(1) // ? in comment", call) is None)
}
