///|
test "parse range lt inclusive" {
  // TODO: parser が `..<=` を対応したら、直接 @parser.parse_string に戻す。
  let source =
    #|fn main {
    #|  for i in 0..<=3 {
    #|    println(i)
    #|  }
    #|  let x = 1
    #|  match x {
    #|    0..<=3 => ()
    #|    _ => ()
    #|  }
    #|}
  let (_, reports) = parse_string_for_lint(
    source,
    name="<range lt inclusive>",
    parser=MoonYacc,
  )
  if reports.length() > 0 {
    fail(reports.to_json().stringify(indent=2))
  }
}
