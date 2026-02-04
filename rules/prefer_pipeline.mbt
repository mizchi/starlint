///|
let prefer_pipeline_rule_id : String = "prefer_pipeline"

///|
let prefer_pipeline_description : String = "Prefer pipeline operator for nested single-argument calls."

///|
priv struct PreferPipelineEnv {
  diags : Array[@moonlint.Diagnostic]
  source : String
}

///|
fn is_allowed_pipe_rhs(func : @syntax.Expr) -> Bool {
  match @moonlint.unwrap_paren(func) {
    @syntax.Ident(..) => true
    @syntax.Method(..) => true
    @syntax.Constr(..) => true
    _ => false
  }
}

///|
fn simple_apply(
  expr : @syntax.Expr,
) -> (@syntax.Expr, @syntax.Expr, @basic.Location)? {
  match @moonlint.unwrap_paren(expr) {
    @syntax.Apply(func~, args~, attr=NoAttr, loc~) => {
      let args_array = @moonlint.list_to_array(args)
      if args_array.length() != 1 {
        return None
      }
      let arg = args_array[0]
      match arg.kind {
        @syntax.ArgumentKind::Positional => Some((func, arg.value, loc))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn collect_chain(
  expr : @syntax.Expr,
) -> (@syntax.Expr, Array[@syntax.Expr], @basic.Location)? {
  let funcs = Array::new(capacity=4)
  let mut current = expr
  let mut outer_loc : @basic.Location? = None
  while true {
    match simple_apply(current) {
      Some((func, arg, loc)) if is_allowed_pipe_rhs(func) => {
        funcs.push(func)
        if outer_loc is None {
          outer_loc = Some(loc)
        }
        current = arg
      }
      Some(_) => return None
      None => break
    }
  }
  if funcs.length() >= 2 {
    match outer_loc {
      Some(loc) => Some((current, funcs, loc))
      None => None
    }
  } else {
    None
  }
}

///|
fn pipeline_suggestion(
  source : String,
  base : @syntax.Expr,
  funcs : Array[@syntax.Expr],
) -> String? {
  let base_src = match @moonlint.expr_source(source, base) {
    Some(src) => src
    None => return None
  }
  let base_text = match @moonlint.unwrap_paren(base) {
    @syntax.Ident(..) => base_src
    @syntax.Constant(..) => base_src
    @syntax.Field(..) => base_src
    @syntax.Apply(..) => base_src
    @syntax.DotApply(..) => base_src
    @syntax.Method(..) => base_src
    @syntax.Constr(..) => base_src
    _ => "(\{base_src})"
  }
  let sb = StringBuilder::new()
  sb..write_view(base_text)
  let mut idx = funcs.length()
  while idx > 0 {
    idx = idx - 1
    let func_src = match @moonlint.expr_source(source, funcs[idx]) {
      Some(src) => src
      None => return None
    }
    sb..write_string(" |> ")..write_view(func_src)
  }
  Some(sb.to_string())
}

///|
impl @syntax.IterVisitor for PreferPipelineEnv with visit_Expr(env, expr) {
  match @moonlint.unwrap_paren(expr) {
    @syntax.Apply(args~, ..) => {
      let args_array = @moonlint.list_to_array(args)
      if args_array.length() != 1 {
        return
      }
    }
    _ => ()
  }
  let mut emitted = false
  match collect_chain(expr) {
    Some((base, funcs, loc)) =>
      match pipeline_suggestion(env.source, base, funcs) {
        Some(suggestion_text) => {
          let message = "Nested calls can be expressed with |> for readability."
          let detail =
            #|f(g(h(x)))
          let suggestion = suggestion_text
          let diag = if loc.start.lnum == loc.end.lnum &&
            !suggestion_text.contains("\n") {
            let replacement = "(\{suggestion_text})"
            let fix = @moonlint.Fix::new(range=loc, replacement~)
            @moonlint.Diagnostic::new(
              rule_id=prefer_pipeline_rule_id,
              loc~,
              message~,
              detail~,
              suggestion~,
              fix~,
            )
          } else {
            @moonlint.Diagnostic::new(
              rule_id=prefer_pipeline_rule_id,
              loc~,
              message~,
              detail~,
              suggestion~,
            )
          }
          env.diags.push(diag)
          emitted = true
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
fn prefer_pipeline_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=prefer_pipeline_rule_id,
    description=prefer_pipeline_description,
    tags=["fp"],
    enabled_by_default=false,
    run=input => {
      let env = PreferPipelineEnv::{
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
