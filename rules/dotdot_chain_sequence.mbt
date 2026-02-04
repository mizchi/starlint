///|
let dotdot_chain_sequence_rule_id : String = "dotdot_chain_sequence"

///|
let dotdot_chain_sequence_description : String = "Consecutive method calls on the same receiver can be chained with .."

///|
priv struct DotdotChainSequenceEnv {
  diags : Array[@moonlint.Diagnostic]
  source : String
}

///|
priv struct DotApplyInfo {
  receiver_key : String
  receiver_expr : @syntax.Expr
  call_expr : @syntax.Expr
}

///|
fn accessor_key(accessor : @syntax.Accessor) -> String {
  match accessor {
    @syntax.Accessor::Label(label) => label.name
    @syntax.Accessor::Index(tuple_index~, loc=_) => "\{tuple_index}"
    @syntax.Accessor::Newtype(loc=_) => "newtype"
  }
}

///|
fn receiver_key(expr : @syntax.Expr) -> String? {
  match @moonlint.unwrap_paren(expr) {
    @syntax.Ident(id=binding, ..) =>
      Some(@moonlint.longident_full_name(binding.name))
    @syntax.Constraint(expr=inner, ..) => receiver_key(inner)
    @syntax.As(expr=inner, ..) => receiver_key(inner)
    @syntax.Field(record~, accessor~, ..) =>
      match receiver_key(record) {
        Some(prefix) => Some("\{prefix}.\{accessor_key(accessor)}")
        None => None
      }
    _ => None
  }
}

///|
fn method_call_info(expr : @syntax.Expr) -> DotApplyInfo? {
  match expr {
    @syntax.DotApply(self~, attr=NoAttr, return_self=false, ..) =>
      match receiver_key(self) {
        Some(key) =>
          Some(DotApplyInfo::{
            receiver_key: key,
            receiver_expr: self,
            call_expr: expr,
          })
        None => None
      }
    @syntax.Apply(func=@syntax.Field(record~, accessor=_, ..), attr=NoAttr, ..) =>
      match receiver_key(record) {
        Some(key) =>
          Some(DotApplyInfo::{
            receiver_key: key,
            receiver_expr: record,
            call_expr: expr,
          })
        None => None
      }
    _ => None
  }
}

///|
fn strip_receiver_prefix(call_src : String, receiver_src : String) -> String? {
  match call_src.strip_prefix("\{receiver_src}..") {
    Some(view) => Some(view.to_string())
    None =>
      match call_src.strip_prefix("\{receiver_src}.") {
        Some(view) => Some(view.to_string())
        None => None
      }
  }
}

///|
fn dotdot_chain_replacement(
  source : String,
  infos : Array[DotApplyInfo],
) -> String? {
  if infos.length() < 2 {
    return None
  }
  let first = infos[0]
  let receiver_src = match @moonlint.expr_source(source, first.receiver_expr) {
    Some(src) => src
    None => return None
  }
  let suffixes = Array::new(capacity=infos.length())
  for info in infos {
    let info_receiver_src = match
      @moonlint.expr_source(source, info.receiver_expr) {
      Some(src) => src
      None => return None
    }
    if info_receiver_src != receiver_src {
      return None
    }
    let call_src = match @moonlint.expr_source(source, info.call_expr) {
      Some(src) => src
      None => return None
    }
    match strip_receiver_prefix(call_src, receiver_src) {
      Some(suffix) => suffixes.push(suffix)
      None => return None
    }
  }
  let sb = StringBuilder::new()
  sb..write_view(receiver_src)
  for suffix in suffixes {
    sb..write_string("..")..write_view(suffix)
  } else {
    Some(sb.to_string())
  }
}

///|
fn sequence_items(
  exprs : @list.List[@syntax.Expr],
  last_expr : @syntax.Expr,
) -> Array[@syntax.Expr] {
  let items = @moonlint.list_to_array(exprs)
  match last_expr {
    @syntax.Unit(faked=true, ..) => items
    _ => {
      items.push(last_expr)
      items
    }
  }
}

///|
fn has_trailing_semicolon(source : String, loc : @basic.Location) -> Bool {
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
impl @syntax.IterVisitor for DotdotChainSequenceEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.Sequence(exprs~, last_expr~, loc~) => {
      let items = sequence_items(exprs, last_expr)
      if items.length() >= 2 {
        let infos = Array::new(capacity=items.length())
        let mut receiver_key : String? = None
        let mut ok = true
        for item in items {
          match method_call_info(item) {
            Some(info) => {
              match receiver_key {
                None => receiver_key = Some(info.receiver_key)
                Some(key) if key == info.receiver_key => ()
                _ => {
                  ok = false
                  break
                }
              }
              infos.push(info)
            }
            None => {
              ok = false
              break
            }
          }
        }
        if ok && infos.length() >= 2 {
          let message = "Consecutive method calls can be chained with .."
          let detail =
            #|obj.a(); obj.b(); obj.c()
          let suggestion =
            #|obj..a()..b()..c()
          let fix = if has_trailing_semicolon(env.source, loc) {
            match dotdot_chain_replacement(env.source, infos) {
              Some(replacement) =>
                Some(@moonlint.Fix::new(range=loc, replacement~))
              None => None
            }
          } else {
            None
          }
          let diag = match fix {
            Some(fix) =>
              @moonlint.Diagnostic::new(
                rule_id=dotdot_chain_sequence_rule_id,
                loc~,
                message~,
                detail~,
                suggestion~,
                fix~,
              )
            None =>
              @moonlint.Diagnostic::new(
                rule_id=dotdot_chain_sequence_rule_id,
                loc~,
                message~,
                detail~,
                suggestion~,
              )
          }
          env.diags.push(diag)
        }
      }
    }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn dotdot_chain_sequence_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=dotdot_chain_sequence_rule_id,
    description=dotdot_chain_sequence_description,
    run=input => {
      let env = DotdotChainSequenceEnv::{
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
