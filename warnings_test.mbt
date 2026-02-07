///|
fn test_lint(source : String) -> Array[@starlint.Diagnostic] raise {
  let (impls, reports) = parse_string_for_lint(source, name="<lint test>")
  if reports.length() > 0 {
    fail(reports.to_json().stringify(indent=2))
  }
  let input = @starlint.LintInput::new(impls~, source~, filename="<lint test>")
  let config = @starlint.LintConfig::enable_categories(["fp", "size", "perf"])
  @starlint.lint_with_config(input, @lint.rules(), config)
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
    content=(
      #|[("match_try_question", <lint test>-2:13-9:4), ("match_try_question", <lint test>-5:7-8:8), ("match_result_try", <lint test>-2:13-9:4), ("match_result_try", <lint test>-5:7-8:8)]
    ),
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

///|
let legacy_call_syntax =
  #|fn main {
  #|  f!(1, 2)
  #|  g?(3)
  #|}

///|
test "legacy call syntax" {
  let diagnostics = test_lint(legacy_call_syntax)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("legacy_call_syntax", <lint test>-2:3-2:11), ("legacy_call_syntax", <lint test>-3:3-3:8)]
    ),
  )
}

///|
let option_map_or_else =
  #|fn main {
  #|  let x = opt.map_or(expensive(), f)
  #|}

///|
test "prefer option map_or_else" {
  let diagnostics = test_lint(option_map_or_else)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"prefer_option_map_or_else\"]")
}

///|
let option_unwrap_or_else =
  #|fn main {
  #|  let x = opt.unwrap_or(expensive())
  #|}

///|
test "prefer option unwrap_or_else" {
  let diagnostics = test_lint(option_unwrap_or_else)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"prefer_option_unwrap_or_else\"]")
}

///|
let string_concat_in_loop =
  #|fn main {
  #|  let mut s = ""
  #|  for i in 0..<3 {
  #|    s = s + "x"
  #|  }
  #|}

///|
test "prefer string builder for concat" {
  let diagnostics = test_lint(string_concat_in_loop)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"prefer_string_builder_for_concat\"]")
}

///|
let string_from_array_large =
  #|fn main {
  #|  let s = String::from_array(['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'])
  #|}

///|
test "avoid string from array large" {
  let diagnostics = test_lint(string_from_array_large)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"avoid_string_from_array_large\"]")
}

///|
let string_substring =
  #|fn main {
  #|  let s = "hello".substring(start=1, end=3)
  #|}

///|
test "prefer string view slice" {
  let diagnostics = test_lint(string_substring)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"prefer_string_view_slice\"]")
}

///|
let string_view_to_string =
  #|fn main {
  #|  let s = "hello"
  #|  let t = s[:][1:3].to_string()
  #|}

///|
test "prefer string view usage" {
  let diagnostics = test_lint(string_view_to_string)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"prefer_string_view_usage\"]")
}

///|
let string_index_access =
  #|fn main {
  #|  for i in 0..<1 {
  #|    let c = "hello"[i]
  #|  }
  #|}

///|
test "prefer unicode safe iteration" {
  let diagnostics = test_lint(string_index_access)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"prefer_unicode_safe_iteration\"]")
}

///|
let map_direct_index =
  #|fn main {
  #|  let m = { "a": 1 }
  #|  let n = m
  #|  let x = n["a"]
  #|}

///|
test "prefer map get pattern" {
  let diagnostics = test_lint(map_direct_index)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"prefer_map_get_pattern\", \"avoid_map_set_js\"]")
}

///|
let map_direct_index_if =
  #|fn main {
  #|  let a = { "a": 1 }
  #|  let b = a
  #|  let m = if flag { a } else { b }
  #|  let x = m["a"]
  #|}

///|
test "prefer map get pattern if" {
  let diagnostics = test_lint(map_direct_index_if)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"prefer_map_get_pattern\", \"avoid_map_set_js\"]")
}

///|
let map_direct_index_assign =
  #|fn main {
  #|  let mut m = { "a": 1 }
  #|  m = { "b": 2 }
  #|  let x = m["b"]
  #|}

///|
test "prefer map get pattern assign" {
  let diagnostics = test_lint(map_direct_index_assign)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(
    summary,
    content="[\"prefer_map_get_pattern\", \"avoid_map_set_js\", \"avoid_map_set_js\"]",
  )
}

///|
let map_direct_index_match =
  #|fn main {
  #|  let a = { "a": 1 }
  #|  let b = { "a": 2 }
  #|  let m = match opt {
  #|    Some(_) => a
  #|    None => b
  #|  }
  #|  let x = m["a"]
  #|}

///|
test "prefer map get pattern match" {
  let diagnostics = test_lint(map_direct_index_match)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(
    summary,
    content="[\"prefer_map_get_pattern\", \"avoid_map_set_js\", \"avoid_map_set_js\"]",
  )
}

///|
let map_direct_index_match_raise =
  #|fn main {
  #|  let a = { "a": 1 }
  #|  let m = match opt {
  #|    Some(_) => a
  #|    None => raise Failure("x")
  #|  }
  #|  let x = m["a"]
  #|}

///|
test "prefer map get pattern match raise" {
  let diagnostics = test_lint(map_direct_index_match_raise)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"prefer_map_get_pattern\", \"avoid_map_set_js\"]")
}

///|
let map_direct_index_match_abort =
  #|fn main {
  #|  let a = { "a": 1 }
  #|  let m = match opt {
  #|    Some(_) => a
  #|    None => abort("x")
  #|  }
  #|  let x = m["a"]
  #|}

///|
test "prefer map get pattern match abort" {
  let diagnostics = test_lint(map_direct_index_match_abort)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"prefer_map_get_pattern\", \"avoid_map_set_js\"]")
}

///|
let map_direct_index_match_panic =
  #|fn main {
  #|  let a = { "a": 1 }
  #|  let m = match opt {
  #|    Some(_) => a
  #|    None => panic()
  #|  }
  #|  let x = m["a"]
  #|}

///|
test "prefer map get pattern match panic" {
  let diagnostics = test_lint(map_direct_index_match_panic)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"prefer_map_get_pattern\", \"avoid_map_set_js\"]")
}

///|
let map_direct_index_match_pkg_panic =
  #|fn main {
  #|  let a = { "a": 1 }
  #|  let m = match opt {
  #|    Some(_) => a
  #|    None => @builtin.panic()
  #|  }
  #|  let x = m["a"]
  #|}

///|
test "prefer map get pattern match pkg panic" {
  let diagnostics = test_lint(map_direct_index_match_pkg_panic)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"prefer_map_get_pattern\", \"avoid_map_set_js\"]")
}

///|
let map_direct_index_try_panic =
  #|fn main {
  #|  let m = try { "a": 1 } catch {
  #|    _ => @builtin.panic()
  #|  }
  #|  let x = m["a"]
  #|}

///|
test "prefer map get pattern try panic" {
  let diagnostics = test_lint(map_direct_index_try_panic)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"prefer_map_get_pattern\", \"avoid_map_set_js\"]")
}

///|
let map_direct_index_try =
  #|fn main {
  #|  let m = try { "a": 1 } catch {
  #|    _ => fail("x")
  #|  }
  #|  let x = m["a"]
  #|}

///|
test "prefer map get pattern try fail" {
  let diagnostics = test_lint(map_direct_index_try)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"prefer_map_get_pattern\", \"avoid_map_set_js\"]")
}

///|
let c_style_for_simple_range =
  #|fn main {
  #|  for i = 0; i < 10; i = i + 1 {
  #|    println(i)
  #|  }
  #|}

///|
test "c style for simple range" {
  let diagnostics = test_lint(c_style_for_simple_range)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("c_style_for_simple_range", <lint test>-2:3-4:4)]
    ),
  )
}

///|
let c_style_for_simple_range_with_continue =
  #|fn main {
  #|  for i = 0; i < 10; i = i + 1 {
  #|    if i % 2 == 0 {
  #|      continue
  #|    }
  #|    println(i)
  #|  }
  #|}

///|
test "c style for simple range with continue" {
  let diagnostics = test_lint(c_style_for_simple_range_with_continue)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
let match_option_do_nothing =
  #|fn main {
  #|  let opt = foo()
  #|  match opt {
  #|    Some(v) => { println(v) }
  #|    None => ()
  #|  }
  #|}

///|
test "match option do nothing" {
  let diagnostics = test_lint(match_option_do_nothing)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
let match_option_do_nothing_last_expr =
  #|fn main {
  #|  let opt = foo()
  #|  match opt {
  #|    Some(_) => ()
  #|    None => ()
  #|  }
  #|}

///|
test "match option do nothing last expr" {
  let diagnostics = test_lint(match_option_do_nothing_last_expr)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("match_option_do_nothing", <lint test>-3:3-6:4)]
    ),
  )
}

///|
let match_option_do_nothing_statement =
  #|fn main {
  #|  let opt = foo()
  #|  match opt {
  #|    Some(v) => println(v)
  #|    None => ()
  #|  }
  #|  ()
  #|}

///|
test "match option do nothing statement" {
  let diagnostics = test_lint(match_option_do_nothing_statement)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("match_option_do_nothing", <lint test>-3:3-6:4)]
    ),
  )
}

///|
let match_option_do_nothing_let_discard =
  #|fn main {
  #|  let opt = foo()
  #|  let _ = match opt {
  #|    Some(v) => println(v)
  #|    None => ()
  #|  }
  #|  ()
  #|}

///|
test "match option do nothing let discard" {
  let diagnostics = test_lint(match_option_do_nothing_let_discard)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("match_option_do_nothing", <lint test>-3:11-6:4)]
    ),
  )
}

///|
let match_option_unwrap_or =
  #|fn main {
  #|  let opt = foo()
  #|  let value = match opt {
  #|    Some(v) => v
  #|    None => 0
  #|  }
  #|}

///|
test "match option unwrap_or" {
  let diagnostics = test_lint(match_option_unwrap_or)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("match_option_unwrap_or", <lint test>-3:15-6:4)]
    ),
  )
}

///|
let match_option_unwrap_or_literal_default =
  #|fn main {
  #|  let opt = foo()
  #|  let value = match opt {
  #|    Some(v) => v
  #|    None => 42
  #|  }
  #|}

///|
test "match option unwrap_or literal default" {
  let diagnostics = test_lint(match_option_unwrap_or_literal_default)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("match_option_unwrap_or", <lint test>-3:15-6:4)]
    ),
  )
}

///|
let match_option_unwrap_or_non_literal_default =
  #|fn main {
  #|  let opt = foo()
  #|  let value = match opt {
  #|    Some(v) => v
  #|    None => expensive()
  #|  }
  #|}

///|
test "match option unwrap_or non literal default" {
  let diagnostics = test_lint(match_option_unwrap_or_non_literal_default)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
let match_option_map =
  #|fn main {
  #|  let opt = foo()
  #|  let value = match opt {
  #|    Some(v) => f(v)
  #|    None => None
  #|  }
  #|}

///|
test "match option map" {
  let diagnostics = test_lint(match_option_map)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("match_option_map", <lint test>-3:15-6:4)]
    ),
  )
}

///|
let match_to_if_let =
  #|fn main {
  #|  let opt = foo()
  #|  let value = match opt {
  #|    Some(v) => f(v)
  #|    None => g()
  #|  }
  #|}

///|
test "match to if let" {
  let diagnostics = test_lint(match_to_if_let)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
let match_to_if_let_statement =
  #|fn main {
  #|  let opt = foo()
  #|  match opt {
  #|    Some(v) => f(v)
  #|    None => g()
  #|  }
  #|  ()
  #|}

///|
test "match to if let statement" {
  let diagnostics = test_lint(match_to_if_let_statement)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("match_to_if_let", <lint test>-3:3-6:4)]
    ),
  )
}

///|
let if_let_to_match =
  #|fn main {
  #|  let opt = foo()
  #|  let value = if opt is Some(v) { f(v) } else { g() }
  #|}

///|
test "if let to match" {
  let diagnostics = test_lint(if_let_to_match)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("if_let_to_match", <lint test>-3:15-3:54)]
    ),
  )
}

///|
let match_result_try =
  #|fn main {
  #|  let x = match (try? f() : Result[Int, Error]) {
  #|    Ok(v) => v
  #|    Err(_) => 0
  #|  }
  #|}

///|
test "match result try" {
  let diagnostics = test_lint(match_result_try)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("match_result_try", <lint test>-2:11-5:4)]
    ),
  )
}

///|
let avoid_map_set_js =
  #|fn main {
  #|  let m : Map[String, Int] = { "a": 1 }
  #|  let n = Map::new()
  #|  let s = Set::new()
  #|}

///|
test "avoid map set js" {
  let diagnostics = test_lint(avoid_map_set_js)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("avoid_map_set_js", <lint test>-2:11-2:27), ("avoid_map_set_js", <lint test>-2:30-2:40), ("avoid_map_set_js", <lint test>-3:11-3:19), ("avoid_map_set_js", <lint test>-4:11-4:19)]
    ),
  )
}

///|
let avoid_json_js =
  #|fn main {
  #|  let x : Json = @json.parse("{}")
  #|  let y = @json.stringify(x)
  #|  let z = Json::Null
  #|}

///|
test "avoid json js" {
  let diagnostics = test_lint(avoid_json_js)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("avoid_json_js", <lint test>-2:11-2:15), ("avoid_json_js", <lint test>-2:18-2:29), ("avoid_json_js", <lint test>-3:11-3:26), ("avoid_json_js", <lint test>-4:11-4:21)]
    ),
  )
}

///|
let avoid_double_to_string_js =
  #|fn main {
  #|  let x = Double::to_string(1.0)
  #|  let y = 1.0.to_string()
  #|}

///|
test "avoid double to_string js" {
  let diagnostics = test_lint(avoid_double_to_string_js)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("avoid_double_to_string_js", <lint test>-2:11-2:28), ("avoid_double_to_string_js", <lint test>-3:11-3:26)]
    ),
  )
}

///|
let dotdot_chain_sequence =
  #|fn main {
  #|  let obj = foo()
  #|  obj.a();
  #|  obj.b(1, 2);
  #|}

///|
test "dotdot chain sequence" {
  let diagnostics = test_lint(dotdot_chain_sequence)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("dotdot_chain_sequence", <lint test>-3:3-4:14)]
    ),
  )
}

///|
let dotdot_chain_sequence_mixed =
  #|fn main {
  #|  obj.a()
  #|  other.b()
  #|}

///|
test "dotdot chain sequence mixed receivers" {
  let diagnostics = test_lint(dotdot_chain_sequence_mixed)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
let dotdot_chain_sequence_field =
  #|fn main {
  #|  let obj = foo()
  #|  obj.field.a();
  #|  obj.field.b();
  #|}

///|
test "dotdot chain sequence field receiver" {
  let diagnostics = test_lint(dotdot_chain_sequence_field)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("dotdot_chain_sequence", <lint test>-3:3-4:16)]
    ),
  )
}

///|
let dotdot_chain_sequence_deep_field =
  #|fn main {
  #|  let obj = foo()
  #|  obj.field.sub.a();
  #|  obj.field.sub.b();
  #|}

///|
test "dotdot chain sequence deep field receiver" {
  let diagnostics = test_lint(dotdot_chain_sequence_deep_field)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("dotdot_chain_sequence", <lint test>-3:3-4:20)]
    ),
  )
}

///|
let dotdot_chain_sequence_value =
  #|fn main {
  #|  let obj = foo()
  #|  let x = { obj.a(); obj.b() }
  #|}

///|
test "dotdot chain sequence value result" {
  let diagnostics = test_lint(dotdot_chain_sequence_value)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("dotdot_chain_sequence", <lint test>-3:13-3:29)]
    ),
  )
}

///|
let dotdot_chain_sequence_call_receiver =
  #|fn main {
  #|  make().a()
  #|  make().b()
  #|}

///|
test "dotdot chain sequence call receiver" {
  let diagnostics = test_lint(dotdot_chain_sequence_call_receiver)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
let dotdot_chain_sequence_called_field =
  #|fn main {
  #|  obj.field().a()
  #|  obj.field().b()
  #|}

///|
test "dotdot chain sequence called field receiver" {
  let diagnostics = test_lint(dotdot_chain_sequence_called_field)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
let prefer_pipeline =
  #|fn main {
  #|  let y = f(g(h(x)))
  #|}

///|
test "prefer pipeline" {
  let diagnostics = test_lint(prefer_pipeline)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("prefer_pipeline", <lint test>-2:11-2:21)]
    ),
  )
}

///|
let prefer_pipeline_method =
  #|fn main {
  #|  let y = Foo::bar(g(x))
  #|}

///|
test "prefer pipeline method" {
  let diagnostics = test_lint(prefer_pipeline_method)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("prefer_pipeline", <lint test>-2:11-2:25)]
    ),
  )
}

///|
let prefer_pipeline_multi_arg =
  #|fn main {
  #|  let y = f(g(x, y))
  #|}

///|
test "prefer pipeline multi arg" {
  let diagnostics = test_lint(prefer_pipeline_multi_arg)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
let prefer_pipeline_rebind_chain =
  #|fn main {
  #|  let b = f(a)
  #|  let c = g(b, 111)
  #|  let d = h(c, 222, 333)
  #|  let e = k(d, 444)
  #|}

///|
test "prefer pipeline rebind chain" {
  let diagnostics = test_lint(prefer_pipeline_rebind_chain)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"prefer_pipeline_rebind\"]")
}

///|
let prefer_pipeline_rebind_mismatch =
  #|fn main {
  #|  let b = f(a)
  #|  let c = g(a, 111)
  #|  let d = h(a)
  #|}

///|
test "prefer pipeline rebind mismatch" {
  let diagnostics = test_lint(prefer_pipeline_rebind_mismatch)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
let prefer_pipeline_rebind_two_steps =
  #|fn main {
  #|  let b = f(a)
  #|  let c = g(b, 1)
  #|}

///|
test "prefer pipeline rebind two steps" {
  let diagnostics = test_lint(prefer_pipeline_rebind_two_steps)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[]")
}

///|
let prefer_pipeline_rebind_non_first_arg =
  #|fn main {
  #|  let b = f(a)
  #|  let c = g(1, b)
  #|  let d = h(c)
  #|}

///|
test "prefer pipeline rebind non first arg" {
  let diagnostics = test_lint(prefer_pipeline_rebind_non_first_arg)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
let prefer_pipeline_rebind_label_arg =
  #|fn main {
  #|  let b = f(a)
  #|  let c = g(x=b, y=1)
  #|  let d = h(c)
  #|}

///|
test "prefer pipeline rebind label arg" {
  let diagnostics = test_lint(prefer_pipeline_rebind_label_arg)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
let prefer_pipeline_rebind_non_apply =
  #|fn main {
  #|  let b = a
  #|  let c = g(b)
  #|}

///|
test "prefer pipeline rebind non apply" {
  let diagnostics = test_lint(prefer_pipeline_rebind_non_apply)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
let prefer_pipeline_outer_multi =
  #|fn main {
  #|  let y = f(g(h(x)), z)
  #|}

///|
test "prefer pipeline outer multi" {
  let diagnostics = test_lint(prefer_pipeline_outer_multi)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
let prefer_pipeline_dot_apply =
  #|fn main {
  #|  let y = obj.f(g(x))
  #|}

///|
test "prefer pipeline dot apply" {
  let diagnostics = test_lint(prefer_pipeline_dot_apply)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
let prefer_arrow_fn =
  #|fn main {
  #|  let f = fn(a){ a }
  #|}

///|
test "prefer arrow fn" {
  let diagnostics = test_lint(prefer_arrow_fn)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("prefer_arrow_fn", <lint test>-2:11-2:21)]
    ),
  )
}

///|
let prefer_eta_reduce =
  #|fn main {
  #|  let f = fn(x){ g(x) }
  #|}

///|
test "prefer eta reduce" {
  let diagnostics = test_lint(prefer_eta_reduce)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("prefer_arrow_fn", <lint test>-2:11-2:24), ("prefer_eta_reduce", <lint test>-2:11-2:24)]
    ),
  )
}

///|
let prefer_eta_reduce_arrow =
  #|fn main {
  #|  let f = (x, y) => h(x, y)
  #|}

///|
test "prefer eta reduce arrow" {
  let diagnostics = test_lint(prefer_eta_reduce_arrow)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("prefer_eta_reduce", <lint test>-2:11-2:28)]
    ),
  )
}

///|
let avoid_side_effect_in_map =
  #|fn main {
  #|  xs.map(f);
  #|}

///|
test "avoid side effect in map" {
  let diagnostics = test_lint(avoid_side_effect_in_map)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("avoid_side_effect_in_map", <lint test>-2:3-2:12)]
    ),
  )
}

///|
let prefer_tuple_destructure =
  #|fn main {
  #|  let a = t.0
  #|  let b = t.1
  #|  foo(a, b)
  #|}

///|
test "prefer tuple destructure" {
  let diagnostics = test_lint(prefer_tuple_destructure)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("prefer_tuple_destructure", <lint test>-2:3-4:12)]
    ),
  )
}

///|
let prefer_tuple_destructure_non_consecutive =
  #|fn main {
  #|  let a = t.0
  #|  let b = t.2
  #|  foo(a, b)
  #|}

///|
test "prefer tuple destructure non consecutive" {
  let diagnostics = test_lint(prefer_tuple_destructure_non_consecutive)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
let prefer_expression_over_return =
  #|fn main {
  #|  return foo()
  #|}

///|
test "prefer expression over return" {
  let diagnostics = test_lint(prefer_expression_over_return)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("prefer_expression_over_return", <lint test>-2:3-2:15)]
    ),
  )
}

///|
let prefer_expression_over_return_sequence =
  #|fn main {
  #|  let x = 1
  #|  return foo(x)
  #|}

///|
test "prefer expression over return sequence" {
  let diagnostics = test_lint(prefer_expression_over_return_sequence)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("prefer_expression_over_return", <lint test>-3:3-3:16)]
    ),
  )
}

///|
let prefer_expression_over_return_early =
  #|fn main {
  #|  if cond { return foo() }
  #|  bar()
  #|}

///|
test "prefer expression over return early" {
  let diagnostics = test_lint(prefer_expression_over_return_early)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
let prefer_array_pattern_match =
  #|fn main {
  #|  let xs = [1, 2, 3]
  #|  match xs.get(0) {
  #|    Some(v) => println(v)
  #|    None => ()
  #|  }
  #|}

///|
test "prefer array pattern match" {
  let diagnostics = test_lint(prefer_array_pattern_match)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("prefer_array_pattern", <lint test>-3:3-6:4)]
    ),
  )
}

///|
let prefer_array_pattern_length =
  #|fn main {
  #|  if xs.length() == 0 { foo() } else { bar() }
  #|}

///|
test "prefer array pattern length" {
  let diagnostics = test_lint(prefer_array_pattern_length)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("prefer_array_pattern", <lint test>-2:3-2:47)]
    ),
  )
}

///|
let prefer_array_pattern_length_no_else =
  #|fn main {
  #|  if xs.length() == 0 { foo() }
  #|}

///|
test "prefer array pattern length no else" {
  let diagnostics = test_lint(prefer_array_pattern_length_no_else)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
let prefer_string_pattern_empty =
  #|fn main {
  #|  if s == "" { foo() } else { bar() }
  #|}

///|
test "prefer string pattern empty" {
  let diagnostics = test_lint(prefer_string_pattern_empty)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("prefer_string_pattern", <lint test>-2:3-2:38)]
    ),
  )
}

///|
let prefer_string_pattern_prefix =
  #|fn main {
  #|  if s.starts_with("let") { foo() } else { bar() }
  #|}

///|
test "prefer string pattern prefix" {
  let diagnostics = test_lint(prefer_string_pattern_prefix)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("prefer_string_pattern", <lint test>-2:3-2:51)]
    ),
  )
}

///|
let avoid_double_option_param =
  #|fn f(a? : Int?) { a }
  #|fn g(b? : String? = None) { b }
  #|fn h(c : Int?) { c }

///|
test "avoid double option param" {
  let diagnostics = test_lint(avoid_double_option_param)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("avoid_double_option_param", <lint test>-1:6-1:15), ("avoid_double_option_param", <lint test>-2:6-2:25)]
    ),
  )
}

///|
let avoid_unnecessary_mut =
  #|fn main {
  #|  let mut x = 1
  #|  let y = x + 1
  #|}

///|
test "avoid unnecessary mut" {
  let diagnostics = test_lint(avoid_unnecessary_mut)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(
    summary,
    content=(
      #|[("avoid_unnecessary_mut", <lint test>-2:3-3:16)]
    ),
  )
}

///|
let avoid_unnecessary_mut_used =
  #|fn main {
  #|  let mut x = 0
  #|  x = x + 1
  #|}

///|
test "avoid unnecessary mut used" {
  let diagnostics = test_lint(avoid_unnecessary_mut_used)
  let summary = diagnostics.map(diag => (diag.rule_id, diag.loc))
  inspect(summary, content="[]")
}

///|
fn test_lint_with_filename(
  source : String,
  filename : String,
  package_files? : Array[String] = [],
) -> Array[@starlint.Diagnostic] raise {
  let (impls, reports) = parse_string_for_lint(source, name=filename)
  if reports.length() > 0 {
    fail(reports.to_json().stringify(indent=2))
  }
  let input = @starlint.LintInput::new(
    impls~,
    source~,
    filename~,
    package_filenames=package_files,
  )
  let config = @starlint.LintConfig::enable_categories(["module"])
  @starlint.lint_with_config(input, @lint.rules(), config)
}

///|
let empty_source =
  #|fn main { () }

///|
test "require snake_case pkg: camelCase detected" {
  let diagnostics = test_lint_with_filename(empty_source, "myPackage/foo.mbt")
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"require_snake_case_pkg\"]")
}

///|
test "require snake_case pkg: snake_case ok" {
  let diagnostics = test_lint_with_filename(empty_source, "my_package/foo.mbt")
  let summary = diagnostics.filter(fn(d) {
    d.rule_id == "require_snake_case_pkg"
  })
  inspect(summary.length(), content="0")
}

///|
test "require snake_case pkg: root file no dir" {
  let diagnostics = test_lint_with_filename(empty_source, "foo.mbt")
  let summary = diagnostics.filter(fn(d) {
    d.rule_id == "require_snake_case_pkg"
  })
  inspect(summary.length(), content="0")
}

///|
test "require snake_case pkg: kebab-case detected" {
  let diagnostics = test_lint_with_filename(empty_source, "my-package/foo.mbt")
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"require_snake_case_pkg\"]")
}

///|
test "require snake_case pkg: camelCase file name detected" {
  let diagnostics = test_lint_with_filename(empty_source, "pkg/myFile.mbt")
  let summary = diagnostics.map(diag => diag.message)
  inspect(
    summary,
    content=(
      #|["File name 'myFile.mbt' is not snake_case."]
    ),
  )
}

///|
test "require snake_case pkg: snake_case file name ok" {
  let diagnostics = test_lint_with_filename(empty_source, "pkg/my_file.mbt")
  let summary = diagnostics.filter(fn(d) {
    d.rule_id == "require_snake_case_pkg"
  })
  inspect(summary.length(), content="0")
}

///|
test "require snake_case pkg: both dir and file bad" {
  let diagnostics = test_lint_with_filename(empty_source, "myPkg/myFile.mbt")
  let summary = diagnostics.map(diag => diag.message)
  inspect(
    summary,
    content=(
      #|["Package directory name 'myPkg' is not snake_case.", "File name 'myFile.mbt' is not snake_case."]
    ),
  )
}

///|
test "prefer test mbt for multi wbtest: warns when no blackbox test file" {
  let diagnostics = test_lint_with_filename(
    empty_source,
    "pkg/foo_wbtest.mbt",
    package_files=["pkg/foo_wbtest.mbt", "pkg/bar_wbtest.mbt", "pkg/main.mbt"],
  )
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"prefer_test_mbt_for_multi_wbtest\"]")
}

///|
test "prefer test mbt for multi wbtest: no warn when _test exists" {
  let diagnostics = test_lint_with_filename(
    empty_source,
    "pkg/foo_wbtest.mbt",
    package_files=[
      "pkg/foo_wbtest.mbt", "pkg/bar_wbtest.mbt", "pkg/all_test.mbt",
    ],
  )
  let summary = diagnostics.filter(fn(d) {
    d.rule_id == "prefer_test_mbt_for_multi_wbtest"
  })
  inspect(summary.length(), content="0")
}

///|
test "prefer test mbt for multi wbtest: warns for each wbtest file" {
  let diagnostics = test_lint_with_filename(
    empty_source,
    "pkg/bar_wbtest.mbt",
    package_files=["pkg/foo_wbtest.mbt", "pkg/bar_wbtest.mbt", "pkg/main.mbt"],
  )
  let summary = diagnostics.filter(fn(d) {
    d.rule_id == "prefer_test_mbt_for_multi_wbtest"
  })
  inspect(summary.length(), content="1")
}
