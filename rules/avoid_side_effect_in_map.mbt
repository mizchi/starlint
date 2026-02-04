///|
let avoid_side_effect_in_map_rule_id : String = "avoid_side_effect_in_map"

///|
let avoid_side_effect_in_map_description : String = "Avoid using map for side effects; use iter().each or a for loop."

///|
priv struct AvoidSideEffectInMapEnv {
  diags : Array[@moonlint.Diagnostic]
  source : String
}

///|
fn map_call_loc(expr : @syntax.Expr) -> @basic.Location? {
  match @moonlint.unwrap_paren(expr) {
    @syntax.DotApply(
      self=_,
      method_name~,
      args~,
      return_self=_,
      attr=NoAttr,
      loc~
    ) =>
      if @moonlint.label_name(method_name) != "map" {
        None
      } else {
        let args_array = @moonlint.list_to_array(args)
        if args_array.length() != 1 {
          None
        } else {
          let arg = args_array[0]
          match arg.kind {
            @syntax.ArgumentKind::Positional => Some(loc)
            _ => None
          }
        }
      }
    @syntax.Apply(
      func=@syntax.Field(record=_, accessor=@syntax.Accessor::Label(label), ..),
      args~,
      attr=NoAttr,
      loc~
    ) =>
      if @moonlint.label_name(label) != "map" {
        None
      } else {
        let args_array = @moonlint.list_to_array(args)
        if args_array.length() != 1 {
          None
        } else {
          let arg = args_array[0]
          match arg.kind {
            @syntax.ArgumentKind::Positional => Some(loc)
            _ => None
          }
        }
      }
    @syntax.Apply(
      func=@syntax.Method(type_name=_, method_name~, ..),
      args~,
      attr=NoAttr,
      loc~
    ) =>
      if @moonlint.label_name(method_name) != "map" {
        None
      } else {
        let args_array = @moonlint.list_to_array(args)
        if args_array.length() != 2 {
          None
        } else {
          let arg = args_array[1]
          match arg.kind {
            @syntax.ArgumentKind::Positional => Some(loc)
            _ => None
          }
        }
      }
    @syntax.Apply(
      func=@syntax.Ident(id={ name: Ident(name~), .. }, ..),
      args~,
      attr=NoAttr,
      loc~
    ) =>
      if name != "map" {
        None
      } else {
        let args_array = @moonlint.list_to_array(args)
        if args_array.length() != 2 {
          None
        } else {
          let arg = args_array[1]
          match arg.kind {
            @syntax.ArgumentKind::Positional => Some(loc)
            _ => None
          }
        }
      }
    _ => None
  }
}

///|
fn map_has_trailing_semicolon(source : String, loc : @basic.Location) -> Bool {
  if source == "" {
    return false
  }
  let start = loc.end.cnum
  if start < 0 || start > source.length() {
    return false
  }
  let view_result : Result[StringView, Error] = try? source[start:]
  match view_result {
    Ok(view) => view.trim_start().has_prefix(";")
    Err(_) => false
  }
}

///|
fn push_avoid_side_effect_in_map_diag(
  env : AvoidSideEffectInMapEnv,
  expr : @syntax.Expr,
  require_semicolon : Bool,
) -> Unit {
  match map_call_loc(expr) {
    Some(loc) =>
      if !require_semicolon || map_has_trailing_semicolon(env.source, loc) {
        let message = "Result of map is unused; use iter().each or a for loop."
        let detail =
          #|xs.map(f)
        let suggestion =
          #|xs.iter().each(f)
        env.diags.push(
          @moonlint.Diagnostic::new(
            rule_id=avoid_side_effect_in_map_rule_id,
            loc~,
            message~,
            detail~,
            suggestion~,
          ),
        )
      }
    None => ()
  }
}

///|
impl @syntax.IterVisitor for AvoidSideEffectInMapEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Let(pattern~, expr=bound, body=_, loc=_) =>
      if @moonlint.is_discard_pattern(pattern) {
        push_avoid_side_effect_in_map_diag(env, bound, false)
      }
    @syntax.LetMut(binder~, ty=_, expr=bound, body=_, loc=_) =>
      if binder.name == "_" {
        push_avoid_side_effect_in_map_diag(env, bound, false)
      }
    _ => ()
  }
  push_avoid_side_effect_in_map_diag(env, expr, true)
  env.base().visit_Expr(expr)
}

///|
fn avoid_side_effect_in_map_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=avoid_side_effect_in_map_rule_id,
    description=avoid_side_effect_in_map_description,
    tags=["fp"],
    enabled_by_default=false,
    run=input => {
      let env = AvoidSideEffectInMapEnv::{
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
