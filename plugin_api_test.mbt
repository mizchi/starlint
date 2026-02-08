///|
fn parse_impls_for_plugin_test(source : String) -> @syntax.Impls raise {
  let (impls, reports) = parse_string_for_lint(source, name="<plugin test>")
  if reports.length() > 0 {
    fail(reports.to_json().stringify(indent=2))
  }
  impls
}

///|
fn plugin_assert_true_literal_rule() -> @starlint.Rule {
  @starlint.Rule::from_plugin(
    id="plugin_assert_true_literal",
    description="Detect assert_true(true) from plugin.",
    tags=["plugin"],
    enabled_by_default=false,
    plugin=ctx => ctx.visit_exprs(expr => match ctx.match_call_info(expr) {
      Some((name, args, loc)) if name == "assert_true" =>
        match ctx.first_positional_arg(args) {
          Some(arg) if ctx.match_constant_bool(arg) == Some(true) => {
            let fix = match ctx.expr_source(arg) {
              Some(arg_src) =>
                Some(
                  @starlint.Fix::new(
                    range=loc,
                    replacement="assert_false(\{arg_src})",
                  ),
                )
              None => None
            }
            ctx.report(
              loc~,
              message="plugin matched assert_true(true)",
              suggestion="assert_true(actual)",
              fix~,
            )
          }
          _ => ()
        }
      _ => ()
    }),
  )
}

///|
test "plugin ctx with extra rules on impls" {
  let source =
    #|test "t" {
    #|  assert_true(true)
    #|}
  let impls = parse_impls_for_plugin_test(source) catch {
    err => fail("\{err}")
  }
  let config = @starlint.LintConfig::enable_categories(["plugin"])
  let diagnostics = @lint.lint_with_extra_rules(
    impls,
    [plugin_assert_true_literal_rule()],
    config~,
  )
  inspect(
    diagnostics.map(d => d.rule_id),
    content="[\"plugin_assert_true_literal\"]",
  )
}

///|
test "plugin ctx with extra rules on source" {
  let source =
    #|test "t" {
    #|  assert_true(true)
    #|}
  let config = @starlint.LintConfig::enable_categories(["plugin"])
  let (diagnostics, reports) = @lint.lint_source_with_extra_rules(
    source,
    [plugin_assert_true_literal_rule()],
    config~,
  )
  inspect(reports.length(), content="0")
  inspect(
    diagnostics.map(d => d.rule_id),
    content="[\"plugin_assert_true_literal\"]",
  )
  let has_fix = diagnostics.length() == 1 && diagnostics[0].fix is Some(_)
  inspect(has_fix, content="true")
}
