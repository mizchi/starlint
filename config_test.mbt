///|
fn rule_enabled(
  rules : Array[@starlint.Rule],
  config : @starlint.LintConfig,
  id : String,
) -> Bool {
  for rule in rules {
    if rule.id == id {
      let (enabled, _) = @starlint.resolve_rule_settings(rule, config)
      return enabled
    }
  }
  false
}

///|
test "recommended preset categories" {
  let rules = @lint.rules()
  let config = @starlint.LintConfig::recommended()
  inspect(
    rule_enabled(rules, config, "prefer_option_map_or_else"),
    content="false",
  )
  inspect(rule_enabled(rules, config, "avoid_json_js"), content="false")
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
  let config = @starlint.LintConfig::from_json(text) catch {
    error => fail("\{error}")
  }
  inspect(
    rule_enabled(rules, config, "prefer_option_map_or_else"),
    content="false",
  )
  inspect(rule_enabled(rules, config, "prefer_arrow_fn"), content="true")
}

///|
test "ignore patterns in config json" {
  let text =
    #|{
    #|  "ignore": ["src/x/ir/parser_moonbit.mbt", "*.gen.mbt"]
    #|}
  let config1 = @starlint.LintConfig::from_json(text) catch {
    error => fail("\{error}")
  }
  inspect(config1.is_ignored("src/x/ir/parser_moonbit.mbt"), content="true")
  let config2 = @starlint.LintConfig::from_json(text) catch {
    error => fail("\{error}")
  }
  inspect(config2.is_ignored("src/x/ir/other.mbt"), content="false")
  let config3 = @starlint.LintConfig::from_json(text) catch {
    error => fail("\{error}")
  }
  inspect(config3.is_ignored("foo.gen.mbt"), content="true")
}

///|
test "overrides by file patterns" {
  let rules = @lint.rules()
  let text =
    #|{
    #|  "preset": "recommended",
    #|  "overrides": [
    #|    {
    #|      "files": ["tests/*", "*_test.mbt"],
    #|      "rules": {
    #|        "prefer_arrow_fn": "off"
    #|      }
    #|    }
    #|  ]
    #|}
  let config = @starlint.LintConfig::from_json(text) catch {
    error => fail("\{error}")
  }
  let test_config = config.for_file("tests/sample.mbt")
  inspect(rule_enabled(rules, test_config, "prefer_arrow_fn"), content="false")
  let base_config = config.for_file("src/main.mbt")
  inspect(rule_enabled(rules, base_config, "prefer_arrow_fn"), content="true")
}
