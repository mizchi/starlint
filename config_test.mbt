///|
fn rule_enabled(
  rules : Array[@moonlint.Rule],
  config : @moonlint.LintConfig,
  id : String,
) -> Bool {
  for rule in rules {
    if rule.id == id {
      let (enabled, _) = @moonlint.resolve_rule_settings(rule, config)
      return enabled
    }
  }
  false
}

///|
test "recommended preset categories" {
  let rules = @lint.rules()
  let config = @moonlint.LintConfig::recommended()
  inspect(
    rule_enabled(rules, config, "prefer_option_map_or_else"),
    content="false",
  )
  inspect(rule_enabled(rules, config, "avoid_json_js"), content="true")
  inspect(
    rule_enabled(rules, config, "async_cancellation_must_propagate"),
    content="true",
  )
  inspect(
    rule_enabled(rules, config, "avoid_abort_in_error_paths"),
    content="true",
  )
  inspect(rule_enabled(rules, config, "prefer_arrow_fn"), content="true")
}

///|
test "preset in config json" {
  let rules = @lint.rules()
  let text =
    #|{
    #|  "preset": "recommended"
    #|}
  let config = @moonlint.LintConfig::from_json(text) catch {
    error => fail("\{error}")
  }
  inspect(
    rule_enabled(rules, config, "prefer_option_map_or_else"),
    content="false",
  )
  inspect(rule_enabled(rules, config, "prefer_arrow_fn"), content="true")
}
