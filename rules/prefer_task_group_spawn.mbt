///|
let prefer_task_group_spawn_rule_id : String = "prefer_task_group_spawn"

///|
let prefer_task_group_spawn_description : String = "Prefer @async.with_task_group over direct async spawn."

///|
priv struct PreferTaskGroupSpawnEnv {
  diags : Array[@starlint.Diagnostic]
}

///|
fn is_async_spawn_call(expr : @syntax.Expr) -> Bool {
  match @starlint.unwrap_paren(expr) {
    @syntax.Apply(func=@syntax.Ident(id=ident, ..), ..) => {
      let name = @starlint.longident_right_name(ident.name)
      match @starlint.longident_pkg_name(ident.name) {
        Some(pkg) => pkg == "async" && (name == "spawn" || name == "spawn_bg")
        None => false
      }
    }
    @syntax.Apply(
      func=@syntax.Field(
        record=@syntax.Ident(id=ident, ..),
        accessor=@syntax.Accessor::Label(label),
        ..
      ),
      ..
    ) => {
      let name = @starlint.label_name(label)
      @starlint.longident_right_name(ident.name) == "async" &&
      (name == "spawn" || name == "spawn_bg")
    }
    _ => false
  }
}

///|
fn push_prefer_task_group_spawn_diag(
  env : PreferTaskGroupSpawnEnv,
  loc : @basic.Location,
) -> Unit {
  let message = "Prefer @async.with_task_group to manage spawned tasks."
  let detail =
    #|@async.spawn(fn() { ... })
  let suggestion =
    #|@async.with_task_group(group => {
    #|  group.spawn(() => { ... })
    #|})
  env.diags.push(
    @starlint.Diagnostic::new(
      rule_id=prefer_task_group_spawn_rule_id,
      loc~,
      message~,
      detail~,
      suggestion~,
    ),
  )
}

///|
impl @syntax.IterVisitor for PreferTaskGroupSpawnEnv with visit_Expr(env, expr) {
  if is_async_spawn_call(expr) {
    push_prefer_task_group_spawn_diag(env, expr.loc())
  }
  env.base().visit_Expr(expr)
}

///|
fn prefer_task_group_spawn_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=prefer_task_group_spawn_rule_id,
    description=prefer_task_group_spawn_description,
    tags=["async"],
    enabled_by_default=false,
    run=input => {
      let env = PreferTaskGroupSpawnEnv::{ diags: Array::new(capacity=4) }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}
