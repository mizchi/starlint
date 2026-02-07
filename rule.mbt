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
