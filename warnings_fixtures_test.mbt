///|
struct WarningFixture {
  name : String
  input : String
  expected : String
}

///|
fn test_lint_for_warning_fixtures(
  source : String,
) -> Array[@moonlint.Diagnostic] raise {
  test_lint_for_warning_fixtures_with_categories(source, ["fp"])
}

///|
fn test_lint_for_warning_fixtures_with_categories(
  source : String,
  categories : Array[String],
) -> Array[@moonlint.Diagnostic] raise {
  let (impls, reports) = @parser.parse_string(source, name="<warning fixture>")
  if reports.length() > 0 {
    fail(reports.to_json().stringify(indent=2))
  }
  let input = @moonlint.LintInput::new(
    impls~,
    source~,
    filename="<warning fixture>",
  )
  let config = @moonlint.LintConfig::enable_categories(categories)
  @moonlint.lint_with_config(input, @lint.rules(), config)
}

///|
fn test_lint_for_warning_fixtures_with_categories_and_filename(
  source : String,
  categories : Array[String],
  filename : String,
) -> Array[@moonlint.Diagnostic] raise {
  let (impls, reports) = @parser.parse_string(source, name=filename)
  if reports.length() > 0 {
    fail(reports.to_json().stringify(indent=2))
  }
  let input = @moonlint.LintInput::new(impls~, source~, filename~)
  let config = @moonlint.LintConfig::enable_categories(categories)
  @moonlint.lint_with_config(input, @lint.rules(), config)
}

///|
test "warning fixtures" {
  let fixtures : Array[WarningFixture] = [
    WarningFixture::{
      name: "match_guard_to_if_basic",
      input: (
        #|fn main {
        #|  match x {
        #|    _ if is_small(x) => handle_small()
        #|    _ if is_large(x) => handle_large()
        #|    _ => handle_other()
        #|  }
        #|}
      ),
      expected: "[\"match_guard_to_if\"]",
    },
    WarningFixture::{
      name: "match_guard_to_if_non_wildcard",
      input: (
        #|fn main {
        #|  match x {
        #|    Some(v) if v > 0 => handle(v)
        #|    _ => ()
        #|  }
        #|}
      ),
      expected: "[]",
    },
    WarningFixture::{
      name: "prefer_guard_chain_nested",
      input: (
        #|fn main {
        #|  match a {
        #|    A(x) => match b {
        #|      B(y) => match c {
        #|        C(z) => work(z)
        #|        _ => ()
        #|      }
        #|      _ => ()
        #|    }
        #|    _ => ()
        #|  }
        #|}
      ),
      expected: "[\"prefer_guard_chain\"]",
    },
    WarningFixture::{
      name: "prefer_guard_chain_with_guard",
      input: (
        #|fn main {
        #|  match a {
        #|    A(x) if x > 0 => match b {
        #|      B(y) => ()
        #|      _ => ()
        #|    }
        #|    _ => ()
        #|  }
        #|}
      ),
      expected: "[]",
    },
  ]
  for fixture in fixtures {
    let _ = fixture.name
    let diagnostics = test_lint_for_warning_fixtures(fixture.input)
    let summary = diagnostics.map(diag => diag.rule_id)
    inspect(summary, content=fixture.expected)
  }
}

///|
test "warning fixtures async/error" {
  let fixtures : Array[WarningFixture] = [
    WarningFixture::{
      name: "async_cancellation_must_propagate",
      input: (
        #|async fn main {
        #|  let _ = foo() catch { _ => None }
        #|}
      ),
      expected: "[\"async_cancellation_must_propagate\"]",
    },
    WarningFixture::{
      name: "async_cancellation_must_propagate_ok",
      input: (
        #|async fn main {
        #|  let _ = foo() catch { error => raise error }
        #|}
      ),
      expected: "[]",
    },
    WarningFixture::{
      name: "prefer_task_group_spawn",
      input: (
        #|fn main {
        #|  @async.spawn(fn() { work() })
        #|}
      ),
      expected: "[\"prefer_task_group_spawn\"]",
    },
    WarningFixture::{
      name: "spawn_result_must_be_used",
      input: (
        #|async fn main {
        #|  let _ = try? foo()
        #|  @async.with_task_group(group => {
        #|    group.spawn(() => work())
        #|    ()
        #|  })
        #|}
      ),
      expected: "[\"spawn_result_must_be_used\"]",
    },
    WarningFixture::{
      name: "spawn_result_must_be_used_ok",
      input: (
        #|async fn main {
        #|  let _ = try? foo()
        #|  @async.with_task_group(group => {
        #|    let task = group.spawn(() => work())
        #|  })
        #|}
      ),
      expected: "[]",
    },
    WarningFixture::{
      name: "spawn_bg_long_running_requires_no_wait",
      input: (
        #|async fn main {
        #|  let _ = try? foo()
        #|  @async.with_task_group(group => {
        #|    group.spawn_bg(() => while true { work() })
        #|  })
        #|}
      ),
      expected: "[\"spawn_bg_long_running_requires_no_wait\"]",
    },
    WarningFixture::{
      name: "spawn_bg_long_running_requires_no_wait_ok",
      input: (
        #|async fn main {
        #|  let _ = try? foo()
        #|  @async.with_task_group(group => {
        #|    group.spawn_bg(() => while true { work() }, no_wait=true)
        #|  })
        #|}
      ),
      expected: "[]",
    },
    WarningFixture::{
      name: "no_wrap_generic_error",
      input: (
        #|suberror WrapA(Error)
      ),
      expected: "[\"no_wrap_generic_error\"]",
    },
    WarningFixture::{
      name: "avoid_abort_in_error_paths",
      input: (
        #|fn main {
        #|  foo() catch { _ => abort("x") }
        #|}
      ),
      expected: "[\"avoid_abort_in_error_paths\"]",
    },
    WarningFixture::{
      name: "prefer_noraise_async",
      input: (
        #|async fn main {
        #|  let x = 1
        #|  x
        #|}
      ),
      expected: "[\"prefer_noraise_async\"]",
    },
    WarningFixture::{
      name: "prefer_noraise_async_ok",
      input: (
        #|async fn main {
        #|  let _ = try? foo()
        #|}
      ),
      expected: "[]",
    },
  ]
  for fixture in fixtures {
    let _ = fixture.name
    let diagnostics = test_lint_for_warning_fixtures_with_categories(
      fixture.input,
      ["async", "error"],
    )
    let summary = diagnostics.map(diag => diag.rule_id)
    inspect(summary, content=fixture.expected)
  }
}

///|
test "warning fixtures test category" {
  let fixtures : Array[WarningFixture] = [
    WarningFixture::{
      name: "avoid_trivial_assert_true",
      input: (
        #|test "t" {
        #|  assert_true(true)
        #|}
      ),
      expected: "[\"avoid_trivial_assert\"]",
    },
    WarningFixture::{
      name: "avoid_trivial_assert_false",
      input: (
        #|test "t" {
        #|  assert_false(true)
        #|}
      ),
      expected: "[\"avoid_trivial_assert\"]",
    },
    WarningFixture::{
      name: "avoid_trivial_assert_eq",
      input: (
        #|test "t" {
        #|  let x = 1
        #|  assert_eq(x, x)
        #|}
      ),
      expected: "[\"avoid_trivial_assert\"]",
    },
    WarningFixture::{
      name: "avoid_trivial_assert_eq_ok",
      input: (
        #|test "t" {
        #|  let x = 1
        #|  assert_eq(x, x + 1)
        #|}
      ),
      expected: "[]",
    },
    WarningFixture::{
      name: "prefer_input_expected_assert",
      input: (
        #|test "t" {
        #|  assert_eq(f(x), 1)
        #|}
      ),
      expected: "[\"prefer_input_expected_assert\"]",
    },
    WarningFixture::{
      name: "prefer_input_expected_assert_ok",
      input: (
        #|test "t" {
        #|  let actual = f(x)
        #|  assert_eq(actual, 1)
        #|}
      ),
      expected: "[]",
    },
  ]
  for fixture in fixtures {
    let _ = fixture.name
    let diagnostics = test_lint_for_warning_fixtures_with_categories(
      fixture.input,
      ["test"],
    )
    let summary = diagnostics.map(diag => diag.rule_id)
    inspect(summary, content=fixture.expected)
  }
}

///|
test "warning fixtures module category" {
  let fixtures : Array[WarningFixture] = [
    WarningFixture::{
      name: "require_doc_pub_fn",
      input: (
        #|pub fn f() { () }
      ),
      expected: "[\"require_doc_pub_fn\"]",
    },
    WarningFixture::{
      name: "require_doc_pub_fn_ok",
      input: (
        #|///|
        #|/// description
        #|pub fn f() { () }
      ),
      expected: "[]",
    },
    WarningFixture::{
      name: "require_doc_pub_enum",
      input: (
        #|pub enum E { A }
      ),
      expected: "[\"require_doc_pub_enum\"]",
    },
    WarningFixture::{
      name: "require_doc_pub_enum_ok",
      input: (
        #|///|
        #|/// description
        #|pub enum E { A }
      ),
      expected: "[]",
    },
    WarningFixture::{
      name: "using_only_in_file",
      input: (
        #|using xpath {type Path}
      ),
      expected: "[\"using_only_in_file\"]",
    },
    WarningFixture::{
      name: "using_only_in_file_ok",
      input: (
        #|using xpath {type Path}
      ),
      expected: "[]",
    },
  ]
  for fixture in fixtures {
    let _ = fixture.name
    let filename = if fixture.name == "using_only_in_file_ok" {
      "file.mbt"
    } else {
      "other.mbt"
    }
    let diagnostics = test_lint_for_warning_fixtures_with_categories_and_filename(
      fixture.input,
      ["module"],
      filename,
    )
    let summary = diagnostics.map(diag => diag.rule_id)
    inspect(summary, content=fixture.expected)
  }
}
