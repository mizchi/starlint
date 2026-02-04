///|
let spawn_bg_long_running_requires_no_wait_rule_id : String = "spawn_bg_long_running_requires_no_wait"

///|
let spawn_bg_long_running_requires_no_wait_description : String = "Long-running spawn_bg should set no_wait=true."

///|
priv struct SpawnBgLongRunningRequiresNoWaitEnv {
  diags : Array[@starlint.Diagnostic]
  task_group_names : Array[String]
}

///|
fn spawn_bg_push_task_group_names(
  env : SpawnBgLongRunningRequiresNoWaitEnv,
  names : Array[String],
) -> Unit {
  for name in names {
    env.task_group_names.push(name)
  }
}

///|
fn spawn_bg_pop_task_group_names(
  env : SpawnBgLongRunningRequiresNoWaitEnv,
  count : Int,
) -> Unit {
  let mut i = 0
  while i < count {
    ignore(env.task_group_names.pop())
    i = i + 1
  }
}

///|
fn spawn_bg_is_task_group_name(
  env : SpawnBgLongRunningRequiresNoWaitEnv,
  name : String,
) -> Bool {
  let mut idx = env.task_group_names.length()
  while idx > 0 {
    idx = idx - 1
    if env.task_group_names[idx] == name {
      return true
    }
  }
  false
}

///|
fn is_task_group_spawn_bg_call(
  env : SpawnBgLongRunningRequiresNoWaitEnv,
  expr : @syntax.Expr,
) -> Bool {
  match @starlint.unwrap_paren(expr) {
    @syntax.DotApply(self~, method_name~, ..) =>
      if @starlint.label_name(method_name) == "spawn_bg" {
        match @starlint.match_ident_name(self) {
          Some(name) => spawn_bg_is_task_group_name(env, name)
          None => false
        }
      } else {
        false
      }
    _ => false
  }
}

///|
fn has_no_wait_arg(args : Array[@syntax.Argument]) -> Bool {
  for arg in args {
    match arg.kind {
      @syntax.ArgumentKind::Labelled(label)
      | @syntax.ArgumentKind::LabelledPun(label)
      | @syntax.ArgumentKind::LabelledOption(label~, ..)
      | @syntax.ArgumentKind::LabelledOptionPun(label~, ..) =>
        if @starlint.label_name(label) == "no_wait" {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn is_infinite_loop_expr(expr : @syntax.Expr) -> Bool {
  match @starlint.unwrap_paren(expr) {
    @syntax.Sequence(exprs~, last_expr~, ..) => {
      let _ = @starlint.list_to_array(exprs)
      is_infinite_loop_expr(last_expr)
    }
    @syntax.While(loop_cond~, while_else~, ..) =>
      match @starlint.match_constant_bool(loop_cond) {
        Some(true) => while_else is None
        _ => false
      }
    _ => false
  }
}

///|
fn push_spawn_bg_no_wait_diag(
  env : SpawnBgLongRunningRequiresNoWaitEnv,
  loc : @basic.Location,
) -> Unit {
  let message = "Long-running spawn_bg should set no_wait=true."
  let detail =
    #|group.spawn_bg(() => while true { ... })
  let suggestion =
    #|group.spawn_bg(() => while true { ... }, no_wait=true)
  env.diags.push(
    @starlint.Diagnostic::new(
      rule_id=spawn_bg_long_running_requires_no_wait_rule_id,
      loc~,
      message~,
      detail~,
      suggestion~,
    ),
  )
}

///|
impl @syntax.IterVisitor for SpawnBgLongRunningRequiresNoWaitEnv with visit_Expr(
  env,
  expr,
) {
  match @starlint.unwrap_paren(expr) {
    @syntax.Apply(func~, args~, ..) =>
      if @starlint.is_async_with_task_group_call(func) {
        let args_array = @starlint.list_to_array(args)
        if args_array.length() > 0 {
          let arg0 = args_array[0]
          match arg0 {
            {
              kind: @syntax.ArgumentKind::Positional,
              value: @syntax.Function(func~, ..),
            } => {
              let names = @starlint.func_param_names(func)
              let count = names.length()
              if count > 0 {
                spawn_bg_push_task_group_names(env, names)
              }
              env.base().visit_Expr(expr)
              if count > 0 {
                spawn_bg_pop_task_group_names(env, count)
              }
              return
            }
            _ => ()
          }
        }
      }
    @syntax.DotApply(args~, ..) =>
      if is_task_group_spawn_bg_call(env, expr) {
        let args_array = @starlint.list_to_array(args)
        if !has_no_wait_arg(args_array) {
          match @starlint.first_positional_arg(args_array) {
            Some(@syntax.Function(func~, ..)) =>
              if is_infinite_loop_expr(func.body) {
                push_spawn_bg_no_wait_diag(env, expr.loc())
              }
            _ => ()
          }
        }
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn spawn_bg_long_running_requires_no_wait_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=spawn_bg_long_running_requires_no_wait_rule_id,
    description=spawn_bg_long_running_requires_no_wait_description,
    tags=["async"],
    enabled_by_default=false,
    run=input => {
      let env = SpawnBgLongRunningRequiresNoWaitEnv::{
        diags: Array::new(capacity=4),
        task_group_names: Array::new(capacity=2),
      }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}
