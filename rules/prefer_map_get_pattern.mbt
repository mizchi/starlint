///|
let prefer_map_get_pattern_rule_id : String = "prefer_map_get_pattern"

///|
let prefer_map_get_pattern_description : String = "Prefer map.get + pattern matching over direct indexing."

///|
priv struct PreferMapGetPatternEnv {
  diags : Array[@moonlint.Diagnostic]
  bindings : Array[MapBinding]
}

///|
priv struct MapBinding {
  name : String
  is_map : Bool
}

///|
fn is_string_key_expr(expr : @syntax.Expr) -> Bool {
  @moonlint.is_string_literal_expr(expr)
}

///|
fn is_map_literal_expr(expr : @syntax.Expr) -> Bool {
  match @moonlint.unwrap_paren(expr) {
    @syntax.Map(..) => true
    _ => false
  }
}

///|
fn is_map_like_expr(env : PreferMapGetPatternEnv, expr : @syntax.Expr) -> Bool {
  if is_map_literal_expr(expr) {
    true
  } else {
    match @moonlint.unwrap_paren(expr) {
      @syntax.If(cond=_, ifso~, ifnot=Some(else_expr), loc=_) =>
        is_map_like_expr(env, ifso) && is_map_like_expr(env, else_expr)
      @syntax.Try(
        body~,
        catch_~,
        catch_all=_,
        try_else~,
        has_try=_,
        try_loc=_,
        catch_loc=_,
        else_loc=_,
        loc=_
      ) => {
        let mut ok = true
        let mut has_map = false
        if !is_non_value_expr(body) {
          if is_map_like_expr(env, body) {
            has_map = true
          } else {
            ok = false
          }
        }
        let catch_array = @moonlint.list_to_array(catch_)
        for case_ in catch_array {
          if ok && !is_non_value_expr(case_.body) {
            if is_map_like_expr(env, case_.body) {
              has_map = true
            } else {
              ok = false
            }
          }
        }
        match try_else {
          Some(else_cases) => {
            let else_array = @moonlint.list_to_array(else_cases)
            for case_ in else_array {
              if ok && !is_non_value_expr(case_.body) {
                if is_map_like_expr(env, case_.body) {
                  has_map = true
                } else {
                  ok = false
                }
              }
            }
          }
          None => ()
        }
        ok && has_map
      }
      @syntax.Match(expr=_, cases~, match_loc=_, loc=_) => {
        let cases_array = @moonlint.list_to_array(cases)
        if cases_array.length() == 0 {
          false
        } else {
          let mut ok = true
          let mut has_map = false
          for case_ in cases_array {
            if is_non_value_expr(case_.body) {
              ()
            } else if is_map_like_expr(env, case_.body) {
              has_map = true
            } else {
              ok = false
            }
          }
          ok && has_map
        }
      }
      _ =>
        match @moonlint.match_ident_name(expr) {
          Some(name) =>
            match lookup_is_map(env, name) {
              Some(true) => true
              _ => false
            }
          None => false
        }
    }
  }
}

///|
fn is_non_value_expr(expr : @syntax.Expr) -> Bool {
  match @moonlint.unwrap_paren(expr) {
    @syntax.Raise(..) => true
    @syntax.Return(..) => true
    @syntax.Break(..) => true
    @syntax.Continue(..) => true
    @syntax.Apply(
      func=@syntax.Field(record=_, accessor=@syntax.Accessor::Label(label), ..),
      args=_,
      attr=NoAttr,
      loc=_
    ) => is_non_value_name(@moonlint.label_name(label))
    @syntax.Apply(
      func=@syntax.Method(type_name=_, method_name~, ..),
      args=_,
      attr=NoAttr,
      loc=_
    ) => is_non_value_name(@moonlint.label_name(method_name))
    @syntax.Apply(func=@syntax.Ident(id=ident, ..), args=_, attr=NoAttr, loc=_) =>
      is_non_value_name(@moonlint.longident_right_name(ident.name))
    @syntax.DotApply(method_name~, ..) =>
      is_non_value_name(@moonlint.label_name(method_name))
    _ => false
  }
}

///|
fn is_non_value_name(name : String) -> Bool {
  name == "abort" || name == "fail" || name == "panic"
}

///|
fn push_binding(
  env : PreferMapGetPatternEnv,
  name : String,
  is_map : Bool,
) -> Unit {
  env.bindings.push(MapBinding::{ name, is_map })
}

///|
fn pop_bindings(env : PreferMapGetPatternEnv, count : Int) -> Unit {
  let mut i = 0
  while i < count {
    ignore(env.bindings.pop())
    i = i + 1
  }
}

///|
fn lookup_is_map(env : PreferMapGetPatternEnv, name : String) -> Bool? {
  let mut idx = env.bindings.length()
  while idx > 0 {
    idx = idx - 1
    let binding = env.bindings[idx]
    if binding.name == name {
      return Some(binding.is_map)
    }
  }
  None
}

///|
fn update_binding(
  env : PreferMapGetPatternEnv,
  name : String,
  is_map : Bool,
) -> Bool {
  let mut idx = env.bindings.length()
  while idx > 0 {
    idx = idx - 1
    let binding = env.bindings[idx]
    if binding.name == name {
      env.bindings[idx] = MapBinding::{ name, is_map }
      return true
    }
  }
  false
}

///|
fn push_pattern_binding(
  env : PreferMapGetPatternEnv,
  pat : @syntax.Pattern,
  is_map : Bool,
) -> Int {
  match pat {
    @syntax.Pattern::Var(binder) =>
      if binder.name == "_" {
        0
      } else {
        push_binding(env, binder.name, is_map)
        1
      }
    _ => 0
  }
}

///|
fn push_param_bindings(
  env : PreferMapGetPatternEnv,
  params : @list.List[@syntax.Parameter],
) -> Int {
  let mut count = 0
  let params_array = @moonlint.list_to_array(params)
  for param in params_array {
    match param {
      @syntax.Parameter::Positional(binder~, ty=_)
      | @syntax.Parameter::Labelled(binder~, ty=_)
      | @syntax.Parameter::Optional(binder~, default=_, ty=_)
      | @syntax.Parameter::QuestionOptional(binder~, ty=_) =>
        if binder.name != "_" {
          push_binding(env, binder.name, false)
          count = count + 1
        }
      _ => ()
    }
  }
  count
}

///|
fn visit_func_body(env : PreferMapGetPatternEnv, func : @syntax.Func) -> Unit {
  let count = push_param_bindings(env, func.parameters)
  env.visit_Expr(func.body)
  pop_bindings(env, count)
}

///|
impl @syntax.IterVisitor for PreferMapGetPatternEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Let(pattern~, expr=bound, body~, loc=_) => {
      env.visit_Expr(bound)
      let count = push_pattern_binding(
        env,
        pattern,
        is_map_like_expr(env, bound),
      )
      env.visit_Expr(body)
      pop_bindings(env, count)
    }
    @syntax.LetMut(binder~, ty=_, expr=bound, body~, loc=_) => {
      env.visit_Expr(bound)
      let count = if binder.name == "_" {
        0
      } else {
        push_binding(env, binder.name, is_map_like_expr(env, bound))
        1
      }
      env.visit_Expr(body)
      pop_bindings(env, count)
    }
    @syntax.Assign(var_~, expr=rhs, augmented_by=_, loc=_) => {
      env.visit_Expr(rhs)
      let name = @moonlint.longident_right_name(var_.name)
      ignore(update_binding(env, name, is_map_like_expr(env, rhs)))
    }
    @syntax.LetFn(name~, func~, body~, loc=_) => {
      visit_func_body(env, func)
      let count = if name.name == "_" {
        0
      } else {
        push_binding(env, name.name, false)
        1
      }
      env.visit_Expr(body)
      pop_bindings(env, count)
    }
    @syntax.LetRec(bindings~, body~, loc=_) => {
      let bindings_array = @moonlint.list_to_array(bindings)
      for binding in bindings_array {
        let (_, func) = binding
        visit_func_body(env, func)
      }
      let mut count = 0
      for binding in bindings_array {
        let (binder, _) = binding
        if binder.name != "_" {
          push_binding(env, binder.name, false)
          count = count + 1
        }
      }
      env.visit_Expr(body)
      pop_bindings(env, count)
    }
    @syntax.LetAnd(bindings~, body~, loc=_) => {
      let bindings_array = @moonlint.list_to_array(bindings)
      for binding in bindings_array {
        let (_, _, func) = binding
        visit_func_body(env, func)
      }
      let mut count = 0
      for binding in bindings_array {
        let (binder, _, _) = binding
        if binder.name != "_" {
          push_binding(env, binder.name, false)
          count = count + 1
        }
      }
      env.visit_Expr(body)
      pop_bindings(env, count)
    }
    @syntax.Function(func~, loc=_) => visit_func_body(env, func)
    @syntax.ArrayGet(array~, index~, loc~) => {
      if is_string_key_expr(index) {
        if is_map_like_expr(env, array) {
          let message = "Direct map indexing can panic; use get + match/guard."
          let detail =
            #|map["key"]
          let suggestion =
            #|match map.get("key") {
            #|  Some(v) => v
            #|  None => ...
            #|}
          env.diags.push(
            @moonlint.Diagnostic::new(
              rule_id=prefer_map_get_pattern_rule_id,
              loc~,
              message~,
              detail~,
              suggestion~,
            ),
          )
        }
      }
      env.base().visit_Expr(expr)
    }
    _ => env.base().visit_Expr(expr)
  }
}

///|
fn prefer_map_get_pattern_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=prefer_map_get_pattern_rule_id,
    description=prefer_map_get_pattern_description,
    tags=["perf"],
    enabled_by_default=false,
    run=input => {
      let env = PreferMapGetPatternEnv::{
        diags: Array::new(capacity=4),
        bindings: Array::new(capacity=4),
      }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}
