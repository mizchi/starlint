///|
test "no hole placeholder" {
  let hole = @syntax.Expr::Hole(
    loc=@syntax.no_location,
    kind=@syntax.Hole::Todo,
  )
  let impls = @list.from_array([
    @syntax.Impl::TopExpr(
      expr=hole,
      is_main=false,
      local_types=@list.new(),
      is_async=None,
      loc=@syntax.no_location,
    ),
  ])
  let input = @starlint.LintInput::new(
    impls~,
    source="",
    filename="<hole test>",
  )
  let config = @starlint.LintConfig::enable_categories(["error"])
  let diagnostics = @starlint.lint_with_config(input, @lint.rules(), config)
  let summary = diagnostics.map(diag => diag.rule_id)
  inspect(summary, content="[\"no_hole_placeholder\"]")
}
