///|
let prefer_pipeline_rebind_rule_id : String = "prefer_pipeline_rebind"

///|
let prefer_pipeline_rebind_description : String = "Prefer |> when let bindings feed into the next call."

///|
let min_rebind_steps : Int = 4

///|
priv struct PreferPipelineRebindEnv {
  diags : Array[@starlint.Diagnostic]
  source : String
}

///|
fn rebind_allowed_pipe_rhs(func : @syntax.Expr) -> Bool {
  match @starlint.unwrap_paren(func) {
    @syntax.Ident(..) => true
    @syntax.Method(..) => true
    @syntax.Constr(..) => true
    _ => false
  }
}

///|
fn rebind_match_ident_like(expr : @syntax.Expr) -> String? {
  match @starlint.unwrap_paren(expr) {
    @syntax.Ident(id={ name: Ident(name~), .. }, ..) => Some(name)
    @syntax.Constraint(expr=inner, ..) => rebind_match_ident_like(inner)
    @syntax.As(expr=inner, ..) => rebind_match_ident_like(inner)
    _ => None
  }
}

///|
fn rebind_parse_simple_apply(
  expr : @syntax.Expr,
) -> (@syntax.Expr, Array[@syntax.Argument], @basic.Location)? {
  match @starlint.unwrap_paren(expr) {
    @syntax.Apply(func~, args~, attr=NoAttr, loc~) =>
      Some((func, @starlint.list_to_array(args), loc))
    _ => None
  }
}

///|
fn rebind_let_chain(
  expr : @syntax.Expr,
) -> (@basic.Location, Array[(String, @syntax.Expr)])? {
  let steps = Array::new(capacity=4)
  let mut current = expr
  let mut outer_loc : @basic.Location? = None
  while true {
    match current {
      @syntax.Let(pattern=@syntax.Pattern::Var(binder), expr=bound, body~, loc~) => {
        if outer_loc is None {
          outer_loc = Some(loc)
        }
        steps.push((binder.name, bound))
        current = body
      }
      _ => break
    }
  }
  if steps.length() >= min_rebind_steps {
    match outer_loc {
      Some(loc) => Some((loc, steps))
      None => None
    }
  } else {
    None
  }
}

///|
fn rebind_call_rhs(
  source : String,
  func : @syntax.Expr,
  args : Array[@syntax.Argument],
) -> String? {
  let func_src = match @starlint.expr_source(source, func) {
    Some(src) => src
    None => return None
  }
  if args.length() == 0 {
    return Some(func_src)
  }
  let sb = StringBuilder::new()
  sb..write_view(func_src)..write_string("(")
  let mut first = true
  for arg in args {
    match arg.kind {
      @syntax.ArgumentKind::Positional => ()
      _ => return None
    }
    let arg_src = match @starlint.expr_source(source, arg.value) {
      Some(src) => src
      None => return None
    }
    if first {
      first = false
    } else {
      sb..write_string(", ")
    }
    sb..write_view(arg_src)
  }
  sb..write_string(")")
  Some(sb.to_string())
}

///|
fn rebind_pipeline_suggestion(
  source : String,
  base : @syntax.Expr,
  steps : Array[(String, @syntax.Expr)],
) -> String? {
  let base_src = match @starlint.expr_source(source, base) {
    Some(src) => src
    None => return None
  }
  let sb = StringBuilder::new()
  sb..write_view(base_src)
  for step in steps {
    let (_, bound_expr) = step
    match rebind_parse_simple_apply(bound_expr) {
      Some((func, args, _)) => {
        if !rebind_allowed_pipe_rhs(func) {
          return None
        }
        if args.length() == 0 {
          return None
        }
        let rest_args = Array::new(capacity=args.length())
        let mut idx = 0
        for arg in args {
          if idx > 0 {
            rest_args.push(arg)
          }
          idx = idx + 1
        }
        let rhs = match rebind_call_rhs(source, func, rest_args) {
          Some(rhs) => rhs
          None => return None
        }
        sb..write_string(" |> ")..write_view(rhs)
      }
      None => return None
    }
  }
  Some(sb.to_string())
}

///|
fn rebind_chain_base_and_steps(
  steps : Array[(String, @syntax.Expr)],
) -> (@syntax.Expr, Array[(String, @syntax.Expr)])? {
  let (first_name, first_expr) = steps[0]
  let (func, args, _) = match rebind_parse_simple_apply(first_expr) {
    Some(v) => v
    None => return None
  }
  if !rebind_allowed_pipe_rhs(func) {
    return None
  }
  if args.length() == 0 {
    return None
  }
  let first_arg = args[0]
  let base = first_arg.value
  if rebind_match_ident_like(base) is None {
    return None
  }
  let mut prev_name = first_name
  let mut idx = 1
  while idx < steps.length() {
    let (name, expr) = steps[idx]
    let (func_i, args_i, _) = match rebind_parse_simple_apply(expr) {
      Some(v) => v
      None => return None
    }
    if !rebind_allowed_pipe_rhs(func_i) {
      return None
    }
    if args_i.length() == 0 {
      return None
    }
    let arg0 = args_i[0]
    match rebind_match_ident_like(arg0.value) {
      Some(arg_name) if arg_name == prev_name => ()
      _ => return None
    }
    prev_name = name
    idx = idx + 1
  }
  Some((base, steps))
}

///|
impl @syntax.IterVisitor for PreferPipelineRebindEnv with visit_Expr(env, expr) {
  let mut emitted = false
  match rebind_let_chain(expr) {
    Some((loc, steps)) =>
      match rebind_chain_base_and_steps(steps) {
        Some((base, steps)) =>
          match rebind_pipeline_suggestion(env.source, base, steps) {
            Some(suggestion) => {
              let message = "Let bindings can be chained with |> for readability."
              let detail =
                #|let b = f(a)
                #|let c = g(b, 111)
                #|let d = h(c, 222, 333)
              let suggestion = suggestion
              let diag = @starlint.Diagnostic::new(
                rule_id=prefer_pipeline_rebind_rule_id,
                loc~,
                message~,
                detail~,
                suggestion~,
              )
              env.diags.push(diag)
              emitted = true
            }
            None => ()
          }
        None => ()
      }
    None => ()
  }
  if !emitted {
    env.base().visit_Expr(expr)
  }
}

///|
fn prefer_pipeline_rebind_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=prefer_pipeline_rebind_rule_id,
    description=prefer_pipeline_rebind_description,
    tags=["fp"],
    enabled_by_default=false,
    run=input => {
      let env = PreferPipelineRebindEnv::{
        diags: Array::new(capacity=8),
        source: input.source,
      }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}
