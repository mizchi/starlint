///|
let prefer_input_expected_assert_rule_id : String = "prefer_input_expected_assert"

///|
let prefer_input_expected_assert_description : String = "Prefer input/expected variables for test assertions."

///|
priv struct PreferInputExpectedAssertEnv {
  diags : Array[@moonlint.Diagnostic]
  mut in_test : Bool
}

///|
fn input_expected_call_name(expr : @syntax.Expr) -> String? {
  match @moonlint.unwrap_paren(expr) {
    @syntax.Ident(id=ident, ..) =>
      Some(@moonlint.longident_right_name(ident.name))
    @syntax.Field(accessor=@syntax.Accessor::Label(label), ..) =>
      Some(@moonlint.label_name(label))
    @syntax.Method(type_name=_, method_name~, ..) =>
      Some(@moonlint.label_name(method_name))
    _ => None
  }
}

///|
fn input_expected_call_info(
  expr : @syntax.Expr,
) -> (String, Array[@syntax.Argument], @basic.Location)? {
  match @moonlint.unwrap_paren(expr) {
    @syntax.Apply(func~, args~, loc~, ..) =>
      match input_expected_call_name(func) {
        Some(name) => Some((name, @moonlint.list_to_array(args), loc))
        None => None
      }
    @syntax.DotApply(method_name~, args~, loc~, ..) =>
      Some(
        (@moonlint.label_name(method_name), @moonlint.list_to_array(args), loc),
      )
    _ => None
  }
}

///|
fn input_expected_first_two_positional_args(
  args : Array[@syntax.Argument],
) -> (@syntax.Expr, @syntax.Expr)? {
  let mut first : @syntax.Expr? = None
  for arg in args {
    if arg.kind is @syntax.ArgumentKind::Positional {
      match first {
        None => first = Some(arg.value)
        Some(lhs) => return Some((lhs, arg.value))
      }
    }
  }
  None
}

///|
fn push_prefer_input_expected_diag(
  env : PreferInputExpectedAssertEnv,
  loc : @basic.Location,
) -> Unit {
  let message = "Prefer input/expected variables for test assertions."
  let detail =
    #|assert_eq(f(x), y)
  let suggestion =
    #|let input = x
    #|let expected = y
    #|let actual = f(input)
    #|assert_eq(actual, expected)
  env.diags.push(
    @moonlint.Diagnostic::new(
      rule_id=prefer_input_expected_assert_rule_id,
      loc~,
      message~,
      detail~,
      suggestion~,
    ),
  )
}

///|
impl @syntax.IterVisitor for PreferInputExpectedAssertEnv with visit_Impl(
  env,
  impl_,
) {
  match impl_ {
    @syntax.Impl::TopTest(..) => {
      let prev = env.in_test
      env.in_test = true
      env.base().visit_Impl(impl_)
      env.in_test = prev
      return
    }
    _ => ()
  }
  env.base().visit_Impl(impl_)
}

///|
impl @syntax.IterVisitor for PreferInputExpectedAssertEnv with visit_Expr(
  env,
  expr,
) {
  match input_expected_call_info(expr) {
    Some((name, args, loc)) if env.in_test && name == "assert_eq" =>
      match input_expected_first_two_positional_args(args) {
        Some((lhs, _rhs)) =>
          if !@moonlint.is_trivial_expr(lhs) && @moonlint.is_call_expr(lhs) {
            push_prefer_input_expected_diag(env, loc)
          }
        None => ()
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn prefer_input_expected_assert_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=prefer_input_expected_assert_rule_id,
    description=prefer_input_expected_assert_description,
    tags=["test"],
    enabled_by_default=false,
    run=input => {
      let env = PreferInputExpectedAssertEnv::{
        diags: Array::new(capacity=4),
        in_test: false,
      }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}
