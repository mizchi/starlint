///|
struct FixFixture {
  name : String
  input : String
  expected : String
  rules : Array[String]
}

///|
fn test_lint_for_fixtures(source : String) -> Array[@moonlint.Diagnostic] raise {
  let (impls, reports) = @parser.parse_string(source, name="<fix test>")
  if reports.length() > 0 {
    fail(reports.to_json().stringify(indent=2))
  }
  let input = @moonlint.LintInput::new(impls~, source~, filename="<fix test>")
  let config = @moonlint.LintConfig::enable_categories(["fp"])
  @moonlint.lint_with_config(input, @lint.rules(), config)
}

///|
fn collect_fixes(
  diagnostics : Array[@moonlint.Diagnostic],
  rule_ids : Array[String],
) -> Array[@moonlint.Fix] {
  let fixes = []
  for diag in diagnostics {
    if rule_ids.contains(diag.rule_id) {
      match diag.fix {
        Some(fix) => fixes.push(fix)
        None => ()
      }
    }
  } else {
    fixes
  }
}

///|
fn apply_fixes_to_source(
  source : String,
  fixes : Array[@moonlint.Fix],
) -> String {
  if fixes.is_empty() {
    return source
  }
  fixes.sort_by((a, b) => b.range.start.cnum - a.range.start.cnum)
  let mut output = source
  let mut prev_start = output.length() + 1
  for fix in fixes {
    let start = fix.range.start.cnum
    let end = fix.range.end.cnum
    if end <= prev_start && 0 <= start && start <= end && end <= output.length() {
      let prefix_result : Result[StringView, Error] = try? output[:start]
      let suffix_result : Result[StringView, Error] = try? output[end:]
      match (prefix_result, suffix_result) {
        (Ok(prefix), Ok(suffix)) => {
          let sb = StringBuilder::new()
          sb
          ..write_view(prefix)
          ..write_string(fix.replacement)
          ..write_view(suffix)
          output = sb.to_string()
          prev_start = start
        }
        _ => ()
      }
    }
  } else {
    output
  }
}

///|
fn apply_fixes_for_rules(
  source : String,
  rule_ids : Array[String],
) -> String raise {
  let diagnostics = test_lint_for_fixtures(source)
  let fixes = collect_fixes(diagnostics, rule_ids)
  apply_fixes_to_source(source, fixes)
}

///|
test "fix fixtures" {
  let fixtures : Array[FixFixture] = [
    FixFixture::{
      name: "prefer_pipeline_simple",
      input: (
        #|fn main {
        #|  let y = f(g(h(x)))
        #|}
      ),
      expected: (
        #|fn main {
        #|  let y = (x |> h |> g |> f)
        #|}
      ),
      rules: ["prefer_pipeline"],
    },
    FixFixture::{
      name: "prefer_pipeline_infix_base",
      input: (
        #|fn main {
        #|  let y = f(g(x + y))
        #|}
      ),
      expected: (
        #|fn main {
        #|  let y = ((x + y) |> g |> f)
        #|}
      ),
      rules: ["prefer_pipeline"],
    },
    FixFixture::{
      name: "prefer_pipeline_if_cond",
      input: (
        #|fn main {
        #|  if f(g(x)) { foo() } else { bar() }
        #|}
      ),
      expected: (
        #|fn main {
        #|  if (x |> g |> f) { foo() } else { bar() }
        #|}
      ),
      rules: ["prefer_pipeline"],
    },
    FixFixture::{
      name: "prefer_pipeline_multiline_no_fix",
      input: (
        #|fn main {
        #|  let y = f(
        #|    g(h(x))
        #|  )
        #|}
      ),
      expected: (
        #|fn main {
        #|  let y = f(
        #|    g(h(x))
        #|  )
        #|}
      ),
      rules: ["prefer_pipeline"],
    },
    FixFixture::{
      name: "prefer_pipeline_inner_multi_arg_no_fix",
      input: (
        #|fn main {
        #|  let y = f(g(x, y))
        #|}
      ),
      expected: (
        #|fn main {
        #|  let y = f(g(x, y))
        #|}
      ),
      rules: ["prefer_pipeline"],
    },
    FixFixture::{
      name: "prefer_pipeline_outer_multi_arg_no_fix",
      input: (
        #|fn main {
        #|  let y = f(g(x), y)
        #|}
      ),
      expected: (
        #|fn main {
        #|  let y = f(g(x), y)
        #|}
      ),
      rules: ["prefer_pipeline"],
    },
    FixFixture::{
      name: "prefer_pipeline_dot_apply_no_fix",
      input: (
        #|fn main {
        #|  let y = obj.f(g(x))
        #|}
      ),
      expected: (
        #|fn main {
        #|  let y = obj.f(g(x))
        #|}
      ),
      rules: ["prefer_pipeline"],
    },
    FixFixture::{
      name: "prefer_arrow_fn_simple_fix",
      input: (
        #|fn main {
        #|  let f = fn(a){ a }
        #|}
      ),
      expected: (
        #|fn main {
        #|  let f = a => a
        #|}
      ),
      rules: ["prefer_arrow_fn"],
    },
    FixFixture::{
      name: "prefer_arrow_fn_map_fix",
      input: (
        #|fn main {
        #|  let ys = items.map(fn(a){ a * 2 })
        #|}
      ),
      expected: (
        #|fn main {
        #|  let ys = items.map(a => a * 2)
        #|}
      ),
      rules: ["prefer_arrow_fn"],
    },
    FixFixture::{
      name: "prefer_arrow_fn_multiline_no_fix",
      input: (
        #|fn main {
        #|  let f = fn(a){
        #|    a
        #|  }
        #|}
      ),
      expected: (
        #|fn main {
        #|  let f = fn(a){
        #|    a
        #|  }
        #|}
      ),
      rules: ["prefer_arrow_fn"],
    },
    FixFixture::{
      name: "prefer_arrow_fn_typed_no_fix",
      input: (
        #|fn main {
        #|  let f = fn(a : Int){ a }
        #|}
      ),
      expected: (
        #|fn main {
        #|  let f = fn(a : Int){ a }
        #|}
      ),
      rules: ["prefer_arrow_fn"],
    },
    FixFixture::{
      name: "prefer_eta_reduce_simple_fix",
      input: (
        #|fn main {
        #|  let f = fn(x){ g(x) }
        #|}
      ),
      expected: (
        #|fn main {
        #|  let f = g
        #|}
      ),
      rules: ["prefer_eta_reduce"],
    },
    FixFixture::{
      name: "prefer_eta_reduce_arrow_fix",
      input: (
        #|fn main {
        #|  let f = (x, y) => h(x, y)
        #|}
      ),
      expected: (
        #|fn main {
        #|  let f = h
        #|}
      ),
      rules: ["prefer_eta_reduce"],
    },
    FixFixture::{
      name: "prefer_tuple_destructure_fix",
      input: (
        #|fn main {
        #|  let a = t.0
        #|  let b = t.1
        #|  foo(a, b)
        #|}
      ),
      expected: (
        #|fn main {
        #|  let (a, b) = t
        #|  foo(a, b)
        #|}
      ),
      rules: ["prefer_tuple_destructure"],
    },
    FixFixture::{
      name: "prefer_expression_over_return_fix",
      input: (
        #|fn main {
        #|  return foo()
        #|}
      ),
      expected: (
        #|fn main {
        #|  foo()
        #|}
      ),
      rules: ["prefer_expression_over_return"],
    },
    FixFixture::{
      name: "prefer_expression_over_return_sequence_fix",
      input: (
        #|fn main {
        #|  let x = 1
        #|  return foo(x)
        #|}
      ),
      expected: (
        #|fn main {
        #|  let x = 1
        #|  foo(x)
        #|}
      ),
      rules: ["prefer_expression_over_return"],
    },
    FixFixture::{
      name: "dotdot_chain_sequence_simple",
      input: (
        #|fn main {
        #|  let obj = foo()
        #|  obj.a();
        #|  obj.b();
        #|}
      ),
      expected: (
        #|fn main {
        #|  let obj = foo()
        #|  obj..a()..b();
        #|}
      ),
      rules: ["dotdot_chain_sequence"],
    },
    FixFixture::{
      name: "dotdot_chain_sequence_no_trailing_semicolon",
      input: (
        #|fn main {
        #|  let obj = foo()
        #|  obj.a();
        #|  obj.b()
        #|}
      ),
      expected: (
        #|fn main {
        #|  let obj = foo()
        #|  obj.a();
        #|  obj.b()
        #|}
      ),
      rules: ["dotdot_chain_sequence"],
    },
    FixFixture::{
      name: "dotdot_chain_sequence_mixed_receivers",
      input: (
        #|fn main {
        #|  obj.a();
        #|  other.b();
        #|}
      ),
      expected: (
        #|fn main {
        #|  obj.a();
        #|  other.b();
        #|}
      ),
      rules: ["dotdot_chain_sequence"],
    },
    FixFixture::{
      name: "dotdot_chain_sequence_field_fix",
      input: (
        #|fn main {
        #|  let obj = foo()
        #|  obj.field.a();
        #|  obj.field.b();
        #|}
      ),
      expected: (
        #|fn main {
        #|  let obj = foo()
        #|  obj.field..a()..b();
        #|}
      ),
      rules: ["dotdot_chain_sequence"],
    },
    FixFixture::{
      name: "dotdot_chain_sequence_deep_field_fix",
      input: (
        #|fn main {
        #|  let obj = foo()
        #|  obj.field.sub.a();
        #|  obj.field.sub.b();
        #|}
      ),
      expected: (
        #|fn main {
        #|  let obj = foo()
        #|  obj.field.sub..a()..b();
        #|}
      ),
      rules: ["dotdot_chain_sequence"],
    },
    FixFixture::{
      name: "dotdot_chain_sequence_call_receiver_no_fix",
      input: (
        #|fn main {
        #|  make().a()
        #|  make().b()
        #|}
      ),
      expected: (
        #|fn main {
        #|  make().a()
        #|  make().b()
        #|}
      ),
      rules: ["dotdot_chain_sequence"],
    },
    FixFixture::{
      name: "dotdot_chain_sequence_called_field_no_fix",
      input: (
        #|fn main {
        #|  obj.field().a()
        #|  obj.field().b()
        #|}
      ),
      expected: (
        #|fn main {
        #|  obj.field().a()
        #|  obj.field().b()
        #|}
      ),
      rules: ["dotdot_chain_sequence"],
    },
    FixFixture::{
      name: "prefer_pipeline_rebind_chain_no_fix",
      input: (
        #|fn main {
        #|  let b = f(a)
        #|  let c = g(b, 111)
        #|  let d = h(c, 222, 333)
        #|}
      ),
      expected: (
        #|fn main {
        #|  let b = f(a)
        #|  let c = g(b, 111)
        #|  let d = h(c, 222, 333)
        #|}
      ),
      rules: ["prefer_pipeline_rebind"],
    },
    FixFixture::{
      name: "prefer_pipeline_rebind_mismatch_no_fix",
      input: (
        #|fn main {
        #|  let b = f(a)
        #|  let c = g(a, 111)
        #|  let d = h(c)
        #|}
      ),
      expected: (
        #|fn main {
        #|  let b = f(a)
        #|  let c = g(a, 111)
        #|  let d = h(c)
        #|}
      ),
      rules: ["prefer_pipeline_rebind"],
    },
    FixFixture::{
      name: "prefer_pipeline_rebind_label_no_fix",
      input: (
        #|fn main {
        #|  let b = f(a)
        #|  let c = g(x=b, y=1)
        #|  let d = h(c)
        #|}
      ),
      expected: (
        #|fn main {
        #|  let b = f(a)
        #|  let c = g(x=b, y=1)
        #|  let d = h(c)
        #|}
      ),
      rules: ["prefer_pipeline_rebind"],
    },
    FixFixture::{
      name: "prefer_pipeline_rebind_non_first_arg_no_fix",
      input: (
        #|fn main {
        #|  let b = f(a)
        #|  let c = g(1, b)
        #|  let d = h(c)
        #|}
      ),
      expected: (
        #|fn main {
        #|  let b = f(a)
        #|  let c = g(1, b)
        #|  let d = h(c)
        #|}
      ),
      rules: ["prefer_pipeline_rebind"],
    },
    FixFixture::{
      name: "c_style_for_simple_range_fix",
      input: (
        #|fn main {
        #|  for i = 0; i < 10; i = i + 1 {
        #|    println(i)
        #|  }
        #|}
      ),
      expected: (
        #|fn main {
        #|  for i in 0..<10 { println(i) }
        #|}
      ),
      rules: ["c_style_for_simple_range"],
    },
    FixFixture::{
      name: "c_style_for_simple_range_inclusive_fix",
      input: (
        #|fn main {
        #|  for i = 1; i <= 3; i = i + 1 { foo(i) }
        #|}
      ),
      expected: (
        #|fn main {
        #|  for i in 1..=3 { foo(i) }
        #|}
      ),
      rules: ["c_style_for_simple_range"],
    },
    FixFixture::{
      name: "c_style_for_simple_range_step_no_fix",
      input: (
        #|fn main {
        #|  for i = 0; i < 10; i = i + 2 { foo(i) }
        #|}
      ),
      expected: (
        #|fn main {
        #|  for i = 0; i < 10; i = i + 2 { foo(i) }
        #|}
      ),
      rules: ["c_style_for_simple_range"],
    },
    FixFixture::{
      name: "match_option_unwrap_or_fix",
      input: (
        #|fn main {
        #|  let opt = foo()
        #|  let value = match opt {
        #|    Some(v) => v
        #|    None => 42
        #|  }
        #|}
      ),
      expected: (
        #|fn main {
        #|  let opt = foo()
        #|  let value = opt.unwrap_or(42)
        #|}
      ),
      rules: ["match_option_unwrap_or"],
    },
    FixFixture::{
      name: "match_option_unwrap_or_guard_no_fix",
      input: (
        #|fn main {
        #|  let opt = foo()
        #|  let value = match opt {
        #|    Some(v) if v > 0 => v
        #|    None => 42
        #|  }
        #|}
      ),
      expected: (
        #|fn main {
        #|  let opt = foo()
        #|  let value = match opt {
        #|    Some(v) if v > 0 => v
        #|    None => 42
        #|  }
        #|}
      ),
      rules: ["match_option_unwrap_or"],
    },
    FixFixture::{
      name: "match_option_unwrap_or_body_no_fix",
      input: (
        #|fn main {
        #|  let opt = foo()
        #|  let value = match opt {
        #|    Some(v) => v + 1
        #|    None => 0
        #|  }
        #|}
      ),
      expected: (
        #|fn main {
        #|  let opt = foo()
        #|  let value = match opt {
        #|    Some(v) => v + 1
        #|    None => 0
        #|  }
        #|}
      ),
      rules: ["match_option_unwrap_or"],
    },
    FixFixture::{
      name: "match_option_map_fix",
      input: (
        #|fn main {
        #|  let opt = foo()
        #|  let value = match opt {
        #|    Some(v) => f(v)
        #|    None => None
        #|  }
        #|}
      ),
      expected: (
        #|fn main {
        #|  let opt = foo()
        #|  let value = opt.map(v => f(v))
        #|}
      ),
      rules: ["match_option_map"],
    },
    FixFixture::{
      name: "match_option_map_guard_no_fix",
      input: (
        #|fn main {
        #|  let opt = foo()
        #|  let value = match opt {
        #|    Some(v) if v > 0 => f(v)
        #|    None => None
        #|  }
        #|}
      ),
      expected: (
        #|fn main {
        #|  let opt = foo()
        #|  let value = match opt {
        #|    Some(v) if v > 0 => f(v)
        #|    None => None
        #|  }
        #|}
      ),
      rules: ["match_option_map"],
    },
    FixFixture::{
      name: "match_option_map_none_not_none_no_fix",
      input: (
        #|fn main {
        #|  let opt = foo()
        #|  let value = match opt {
        #|    Some(v) => f(v)
        #|    None => Some(0)
        #|  }
        #|}
      ),
      expected: (
        #|fn main {
        #|  let opt = foo()
        #|  let value = match opt {
        #|    Some(v) => f(v)
        #|    None => Some(0)
        #|  }
        #|}
      ),
      rules: ["match_option_map"],
    },
    FixFixture::{
      name: "match_to_if_let_statement_fix",
      input: (
        #|fn main {
        #|  let opt = foo()
        #|  match opt {
        #|    Some(v) => f(v)
        #|    None => g()
        #|  }
        #|  ()
        #|}
      ),
      expected: (
        #|fn main {
        #|  let opt = foo()
        #|  if (opt) is Some(v) { f(v) } else { g() }
        #|  ()
        #|}
      ),
      rules: ["match_to_if_let"],
    },
    FixFixture::{
      name: "match_option_do_nothing_fix",
      input: (
        #|fn main {
        #|  let opt = foo()
        #|  match opt {
        #|    Some(v) => { println(v) }
        #|    None => ()
        #|  }
        #|}
      ),
      expected: (
        #|fn main {
        #|  let opt = foo()
        #|  match opt {
        #|    Some(v) => { println(v) }
        #|    None => ()
        #|  }
        #|}
      ),
      rules: ["match_option_do_nothing"],
    },
    FixFixture::{
      name: "match_option_do_nothing_statement_fix",
      input: (
        #|fn main {
        #|  let opt = foo()
        #|  match opt {
        #|    Some(v) => println(v)
        #|    None => ()
        #|  }
        #|  ()
        #|}
      ),
      expected: (
        #|fn main {
        #|  let opt = foo()
        #|  if (opt) is Some(v) { println(v) }
        #|  ()
        #|}
      ),
      rules: ["match_option_do_nothing"],
    },
    FixFixture::{
      name: "match_option_do_nothing_last_expr_unit_fix",
      input: (
        #|fn main {
        #|  let opt = foo()
        #|  match opt {
        #|    Some(_) => ()
        #|    None => ()
        #|  }
        #|}
      ),
      expected: (
        #|fn main {
        #|  let opt = foo()
        #|  if (opt) is Some(_) { () }
        #|}
      ),
      rules: ["match_option_do_nothing"],
    },
    FixFixture::{
      name: "match_option_do_nothing_let_discard_fix",
      input: (
        #|fn main {
        #|  let opt = foo()
        #|  let _ = match opt {
        #|    Some(v) => println(v)
        #|    None => ()
        #|  }
        #|  ()
        #|}
      ),
      expected: (
        #|fn main {
        #|  let opt = foo()
        #|  let _ = if (opt) is Some(v) { println(v) }
        #|  ()
        #|}
      ),
      rules: ["match_option_do_nothing"],
    },
    FixFixture::{
      name: "match_option_do_nothing_non_unit_no_fix",
      input: (
        #|fn main {
        #|  let opt = foo()
        #|  match opt {
        #|    Some(v) => { println(v) }
        #|    None => bar()
        #|  }
        #|}
      ),
      expected: (
        #|fn main {
        #|  let opt = foo()
        #|  match opt {
        #|    Some(v) => { println(v) }
        #|    None => bar()
        #|  }
        #|}
      ),
      rules: ["match_option_do_nothing"],
    },
    FixFixture::{
      name: "legacy_call_syntax_bang_fix",
      input: (
        #|fn main {
        #|  f!(1, 2)
        #|}
      ),
      expected: (
        #|fn main {
        #|  f(1, 2)
        #|}
      ),
      rules: ["legacy_call_syntax"],
    },
    FixFixture::{
      name: "legacy_call_syntax_bang_space_fix",
      input: (
        #|fn main {
        #|  f! (1, 2)
        #|}
      ),
      expected: (
        #|fn main {
        #|  f (1, 2)
        #|}
      ),
      rules: ["legacy_call_syntax"],
    },
    FixFixture::{
      name: "legacy_call_syntax_question_fix",
      input: (
        #|fn main {
        #|  g?(3)
        #|}
      ),
      expected: (
        #|fn main {
        #|  try? g(3)
        #|}
      ),
      rules: ["legacy_call_syntax"],
    },
    FixFixture::{
      name: "legacy_call_syntax_question_space_fix",
      input: (
        #|fn main {
        #|  g? (3)
        #|}
      ),
      expected: (
        #|fn main {
        #|  try? g (3)
        #|}
      ),
      rules: ["legacy_call_syntax"],
    },
    FixFixture::{
      name: "legacy_call_syntax_normal_no_fix",
      input: (
        #|fn main {
        #|  h(4)
        #|}
      ),
      expected: (
        #|fn main {
        #|  h(4)
        #|}
      ),
      rules: ["legacy_call_syntax"],
    },
  ]
  for fixture in fixtures {
    let output = apply_fixes_for_rules(fixture.input, fixture.rules) catch {
      err => fail("fixture \{fixture.name} raised: \{err}")
    }
    if output != fixture.expected {
      let diagnostics = test_lint_for_fixtures(fixture.input) catch {
        err => fail("fixture \{fixture.name} lint failed: \{err}")
      }
      let fixes = collect_fixes(diagnostics, fixture.rules)
      let mut diag_count = 0
      for diag in diagnostics {
        if fixture.rules.contains(diag.rule_id) {
          diag_count += 1
        }
      }
      let sb = StringBuilder::new()
      sb
      ..write_string("fixture ")
      ..write_string(fixture.name)
      ..write_string(" mismatch\n")
      ..write_string("diagnostics: ")
      ..write_string(diag_count.to_string())
      ..write_string(", fixes: ")
      ..write_string(fixes.length().to_string())
      ..write_string("\n--- expected ---\n")
      ..write_string(fixture.expected)
      ..write_string("\n--- actual ---\n")
      ..write_string(output)
      fail(sb.to_string())
    }
  }
}
