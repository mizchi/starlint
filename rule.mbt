///|
pub struct LintInput {
  impls : @syntax.Impls
  source : String
  filename : String
  package_filenames : Array[String]
}

///|
pub fn LintInput::new(
  impls~ : @syntax.Impls,
  source~ : String,
  filename~ : String,
  package_filenames? : Array[String] = [],
) -> LintInput {
  { impls, source, filename, package_filenames }
}

///|
pub type RuleRunner = (LintInput) -> Array[Diagnostic]

///|
pub type RulePluginRunner = (LintPluginContext) -> Unit

///|
pub struct Rule {
  id : String
  description : String
  run : RuleRunner
  tags : Array[String]
  default_severity : Severity
  enabled_by_default : Bool
}

///|
pub fn Rule::new(
  id~ : String,
  description~ : String,
  run~ : RuleRunner,
  tags? : Array[String] = [],
  default_severity? : Severity = Severity::Warning,
  enabled_by_default? : Bool = true,
) -> Rule {
  { id, description, run, tags, default_severity, enabled_by_default }
}

///|
pub fn Rule::apply(self : Rule, input : LintInput) -> Array[Diagnostic] {
  (self.run)(input)
}

///|
pub fn Rule::from_plugin(
  id~ : String,
  description~ : String,
  plugin~ : RulePluginRunner,
  tags? : Array[String] = [],
  default_severity? : Severity = Severity::Warning,
  enabled_by_default? : Bool = true,
) -> Rule {
  Rule::new(
    id~,
    description~,
    run=input => {
      let ctx = LintPluginContext::{
        rule_id: id,
        input,
        diagnostics: Array::new(capacity=8),
      }
      plugin(ctx)
      ctx.diagnostics
    },
    tags~,
    default_severity~,
    enabled_by_default~,
  )
}
