///|
let spawn_result_must_be_used_rule_id : String = "spawn_result_must_be_used"

///|
let spawn_result_must_be_used_description : String = "Do not ignore TaskGroup spawn results."

///|
priv struct SpawnResultMustBeUsedEnv {
  diags : Array[@moonlint.Diagnostic]
  task_group_names : Array[String]
}

///|
fn is_with_task_group_call(expr : @syntax.Expr) -> Bool {
  match @moonlint.unwrap_paren(expr) {
    @syntax.Ident(id=ident, ..) => {
      let name = @moonlint.longident_right_name(ident.name)
      match @moonlint.longident_pkg_name(ident.name) {
        Some(pkg) => pkg == "async" && name == "with_task_group"
        None => false
      }
    }
    @syntax.Field(
      record=@syntax.Ident(id=ident, ..),
      accessor=@syntax.Accessor::Label(label),
      ..
    ) =>
      @moonlint.label_name(label) == "with_task_group" &&
      @moonlint.longident_right_name(ident.name) == "async"
    _ => false
  }
}

///|
fn task_group_param_names(func : @syntax.Func) -> Array[String] {
  let params = @moonlint.list_to_array(func.parameters)
  let names = Array::new(capacity=params.length())
  for param in params {
    match param {
      @syntax.Parameter::Positional(binder~, ty=_) =>
        if binder.name != "_" {
          names.push(binder.name)
        }
      @syntax.Parameter::Labelled(binder~, ty=_) =>
        if binder.name != "_" {
          names.push(binder.name)
        }
      _ => ()
    }
  } else {
    names
  }
}

///|
fn push_task_group_names(
  env : SpawnResultMustBeUsedEnv,
  names : Array[String],
) -> Unit {
  for name in names {
    env.task_group_names.push(name)
  }
}

///|
fn pop_task_group_names(env : SpawnResultMustBeUsedEnv, count : Int) -> Unit {
  let mut i = 0
  while i < count {
    ignore(env.task_group_names.pop())
    i = i + 1
  }
}

///|
fn is_task_group_name(env : SpawnResultMustBeUsedEnv, name : String) -> Bool {
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
fn is_task_group_spawn_call(
  env : SpawnResultMustBeUsedEnv,
  expr : @syntax.Expr,
) -> Bool {
  match @moonlint.unwrap_paren(expr) {
    @syntax.DotApply(self~, method_name~, ..) =>
      if @moonlint.label_name(method_name) == "spawn" {
        match @moonlint.match_ident_name(self) {
          Some(name) => is_task_group_name(env, name)
          None => false
        }
      } else {
        false
      }
    _ => false
  }
}

///|
fn push_spawn_result_unused_diag(
  env : SpawnResultMustBeUsedEnv,
  loc : @basic.Location,
) -> Unit {
  let message = "TaskGroup spawn result is unused; assign it or use spawn_bg."
  let detail =
    #|group.spawn(() => { ... })
  let suggestion =
    #|let task = group.spawn(() => { ... })
  env.diags.push(
    @moonlint.Diagnostic::new(
      rule_id=spawn_result_must_be_used_rule_id,
      loc~,
      message~,
      detail~,
      suggestion~,
    ),
  )
}

///|
impl @syntax.IterVisitor for SpawnResultMustBeUsedEnv with visit_Expr(env, expr) {
  match @moonlint.unwrap_paren(expr) {
    @syntax.Apply(func~, args~, ..) =>
      if is_with_task_group_call(func) {
        let args_array = @moonlint.list_to_array(args)
        if args_array.length() > 0 {
          let arg0 = args_array[0]
          match arg0 {
            {
              kind: @syntax.ArgumentKind::Positional,
              value: @syntax.Function(func~, ..),
            } => {
              let names = task_group_param_names(func)
              let count = names.length()
              if count > 0 {
                push_task_group_names(env, names)
              }
              env.base().visit_Expr(expr)
              if count > 0 {
                pop_task_group_names(env, count)
              }
              return
            }
            _ => ()
          }
        }
      }
    @syntax.Sequence(exprs~, ..) => {
      let items = @moonlint.list_to_array(exprs)
      for stmt in items {
        if is_task_group_spawn_call(env, stmt) {
          push_spawn_result_unused_diag(env, stmt.loc())
        }
      }
    }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn spawn_result_must_be_used_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=spawn_result_must_be_used_rule_id,
    description=spawn_result_must_be_used_description,
    tags=["async"],
    enabled_by_default=false,
    run=input => {
      let env = SpawnResultMustBeUsedEnv::{
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
