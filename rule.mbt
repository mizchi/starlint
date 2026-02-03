///|
pub struct LintInput {
  impls : @syntax.Impls
  source : String
  filename : String
}

///|
pub fn LintInput::new(
  impls~ : @syntax.Impls,
  source~ : String,
  filename~ : String,
) -> LintInput {
  { impls, source, filename }
}

///|
pub type RuleRunner = (LintInput) -> Array[Diagnostic]

///|
pub struct Rule {
  id : String
  description : String
  run : RuleRunner
}

///|
pub fn Rule::new(
  id~ : String,
  description~ : String,
  run~ : RuleRunner,
) -> Rule {
  { id, description, run }
}

///|
pub fn Rule::run(self : Rule, input : LintInput) -> Array[Diagnostic] {
  self.run(input)
}
