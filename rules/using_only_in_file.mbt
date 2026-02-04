///|
let using_only_in_file_rule_id : String = "using_only_in_file"

///|
let using_only_in_file_description : String = "Using statements are only allowed in a designated file."

///|
let using_allowed_filename : String = "file.mbt"

///|
priv struct UsingOnlyInFileEnv {
  diags : Array[@moonlint.Diagnostic]
  filename : String
}

///|
fn string_has_suffix(value : String, suffix : String) -> Bool {
  if value.length() < suffix.length() {
    return false
  }
  let start = value.length() - suffix.length()
  let view_result : Result[StringView, Error] = try? value[start:]
  match view_result {
    Ok(view) => view == suffix
    Err(_) => false
  }
}

///|
fn is_allowed_using_file(filename : String) -> Bool {
  filename == using_allowed_filename ||
  string_has_suffix(filename, "/" + using_allowed_filename)
}

///|
fn push_using_only_in_file_diag(
  env : UsingOnlyInFileEnv,
  loc : @basic.Location,
) -> Unit {
  let message = "using is only allowed in the designated file (file.mbt)."
  let detail =
    #|using @pkg { type Foo }
  let suggestion =
    #|Move this using to file.mbt
  env.diags.push(
    @moonlint.Diagnostic::new(
      rule_id=using_only_in_file_rule_id,
      loc~,
      message~,
      detail~,
      suggestion~,
    ),
  )
}

///|
impl @syntax.IterVisitor for UsingOnlyInFileEnv with visit_Impl(env, impl_) {
  match impl_ {
    @syntax.Impl::TopUsing(loc~, ..) =>
      if !is_allowed_using_file(env.filename) {
        push_using_only_in_file_diag(env, loc)
      }
    _ => ()
  }
  env.base().visit_Impl(impl_)
}

///|
fn using_only_in_file_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=using_only_in_file_rule_id,
    description=using_only_in_file_description,
    tags=["module"],
    enabled_by_default=false,
    run=input => {
      let env = UsingOnlyInFileEnv::{
        diags: Array::new(capacity=4),
        filename: input.filename,
      }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}
