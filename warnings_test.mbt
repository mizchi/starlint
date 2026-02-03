///|
fn test_lint(source : String) -> Array[@moonlint.Diagnostic] raise {
  let (impls, reports) = @parser.parse_string(source, name="<lint test>")
  if reports.length() > 0 {
    fail(reports.to_json().stringify(indent=2))
  }
  let input = @moonlint.LintInput::new(impls~, source~, filename="<lint test>")
  @moonlint.lint(input, @lint.rules())
}

///|
let match_try_question =
  #|fn main {
  #|  let foo = match (try? f()) {
  #|    Ok(_) => "ok"
  #|    Err(_) =>
  #|      match (try? f()) {
  #|        Ok(_) => "ok"
  #|        Err(_) => "failed"
  #|      }
  #|  }
  #|  println(foo)
  #|}

///|
test "match try?" {
  let diagnostics = test_lint(match_try_question)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content="[(\"match_try_question\", <lint test>-2:13-9:4), (\"match_try_question\", <lint test>-5:7-8:8)]",
  )
}

///|
let string_literal_multiply_number =
  #|fn main {
  #|  let x = "hello" * 3
  #|}

///|
test "string literal multiply number" {
  let diagnostics = test_lint(string_literal_multiply_number)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content="[(\"string_literal_multiply_number\", <lint test>-2:11-2:22)]",
  )
}

///|
let boolean_if_true_false =
  #|fn main {
  #|  let x = if flag { true } else { false }
  #|}

///|
test "boolean if true false" {
  let diagnostics = test_lint(boolean_if_true_false)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content="[(\"boolean_if_true_false\", <lint test>-2:11-2:42)]",
  )
}

///|
let boolean_if_false_true =
  #|fn main {
  #|  let x = if flag { false } else { true }
  #|}

///|
test "boolean if false true" {
  let diagnostics = test_lint(boolean_if_false_true)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content="[(\"boolean_if_false_true\", <lint test>-2:11-2:42)]",
  )
}

///|
let redundant_if_same_branch =
  #|fn main {
  #|  let x = if flag { foo } else { foo }
  #|}

///|
test "redundant if same branch" {
  let diagnostics = test_lint(redundant_if_same_branch)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content="[(\"redundant_if_same_branch\", <lint test>-2:11-2:39)]",
  )
}
