///|
test "parse match expr in infix" {
  let source =
    #|fn main {
    #|  let x = 1
    #|  let y = 1 + match x {
    #|    0 => 1
    #|    _ => 2
    #|  }
    #|  println(y)
    #|}
  let (_, reports) = parse_string_for_lint(
    source,
    name="<match expr>",
    parser=MoonYacc,
  )
  if reports.length() > 0 {
    fail(reports.to_json().stringify(indent=2))
  }
}

///|
test "parse match expr in infix with record" {
  let source =
    #|fn main {
    #|  let x = 1
    #|  let y = 1 + match x {
    #|    0 => { a: 1 }
    #|    _ => { a: 2 }
    #|  }
    #|  println(y)
    #|}
  let (_, reports) = parse_string_for_lint(
    source,
    name="<match expr record>",
    parser=MoonYacc,
  )
  if reports.length() > 0 {
    fail(reports.to_json().stringify(indent=2))
  }
}

///|
test "parse invalid match keeps errors" {
  let source =
    #|fn main {
    #|  let y = 1 + match 0 {
    #|    0 => 1
    #|  let z = 2
    #|}
  let (_, reports) = parse_string_for_lint(
    source,
    name="<invalid match>",
    parser=MoonYacc,
  )
  if reports.length() == 0 {
    fail("expected parse error")
  }
}
