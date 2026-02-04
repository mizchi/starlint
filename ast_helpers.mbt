///|
pub fn unwrap_paren(expr : @syntax.Expr) -> @syntax.Expr {
  match expr {
    @syntax.Group(expr=inner, group=Paren, loc=_) => unwrap_paren(inner)
    _ => expr
  }
}

///|
pub fn match_infix(
  expr : @syntax.Expr,
  op_name : String,
) -> (@syntax.Expr, @syntax.Expr, @basic.Location)? {
  match unwrap_paren(expr) {
    @syntax.Infix(op={ name: Ident(name~), .. }, lhs~, rhs~, loc~) if name ==
      op_name => Some((lhs, rhs, loc))
    _ => None
  }
}

///|
pub fn match_constant_string(expr : @syntax.Expr) -> String? {
  match unwrap_paren(expr) {
    @syntax.Constant(c=String(value), ..) => Some(value)
    _ => None
  }
}

///|
pub fn match_constant_int(expr : @syntax.Expr) -> String? {
  match unwrap_paren(expr) {
    @syntax.Constant(c=Int(value), ..) => Some(value)
    _ => None
  }
}

///|
pub fn is_string_literal_expr(expr : @syntax.Expr) -> Bool {
  match unwrap_paren(expr) {
    @syntax.Constant(c=String(_), ..) => true
    @syntax.MultilineString(..) => true
    @syntax.Interp(..) => true
    _ => false
  }
}

///|
pub fn is_call_expr(expr : @syntax.Expr) -> Bool {
  match unwrap_paren(expr) {
    @syntax.Apply(..) => true
    @syntax.DotApply(..) => true
    _ => false
  }
}

///|
pub fn match_ident_name(expr : @syntax.Expr) -> String? {
  match unwrap_paren(expr) {
    @syntax.Ident(id={ name: Ident(name~), .. }, ..) => Some(name)
    _ => None
  }
}

///|
pub fn constructor_name(constr : @syntax.Constructor) -> String {
  let { name, .. } = constr
  name.name
}

///|
pub fn constructor_type_name(constr : @syntax.Constructor) -> String? {
  match constr.extra_info {
    @syntax.ConstructorExtraInfo::TypeName(type_name) =>
      type_name.name |> longident_right_name |> Some
    _ => None
  }
}

///|
pub fn longident_right_name(id : @syntax.LongIdent) -> String {
  match id {
    @syntax.LongIdent::Ident(name~) => name
    @syntax.LongIdent::Dot(pkg=_, id~) => id
  }
}

///|
pub fn longident_pkg_name(id : @syntax.LongIdent) -> String? {
  match id {
    @syntax.LongIdent::Dot(pkg~, id=_) => Some(pkg)
    _ => None
  }
}

///|
pub fn longident_full_name(id : @syntax.LongIdent) -> String {
  match id {
    @syntax.LongIdent::Ident(name~) => name
    @syntax.LongIdent::Dot(pkg~, id~) => "\{pkg}.\{id}"
  }
}

///|
pub fn type_name_right_name(type_name : @syntax.TypeName) -> String {
  longident_right_name(type_name.name)
}

///|
pub fn constr_id_right_name(constr_id : @syntax.ConstrId) -> String {
  longident_right_name(constr_id.id)
}

///|
pub fn constr_id_pkg_name(constr_id : @syntax.ConstrId) -> String? {
  longident_pkg_name(constr_id.id)
}

///|
pub fn label_name(label : @syntax.Label) -> String {
  label.name
}

///|
pub fn[T] list_to_array(xs : @list.List[T]) -> Array[T] {
  let out = Array::new(capacity=4)
  for item in xs {
    out.push(item)
  } else {
    out
  }
}

///|
pub fn match_callable_name(expr : @syntax.Expr) -> String? {
  match unwrap_paren(expr) {
    @syntax.Ident(id=ident, ..) => Some(longident_right_name(ident.name))
    @syntax.Field(accessor=@syntax.Accessor::Label(label), ..) =>
      Some(label_name(label))
    @syntax.Method(type_name=_, method_name~, ..) =>
      Some(label_name(method_name))
    _ => None
  }
}

///|
pub fn match_call_name(expr : @syntax.Expr) -> String? {
  match unwrap_paren(expr) {
    @syntax.Apply(func~, ..) => match_callable_name(func)
    @syntax.DotApply(method_name~, ..) => Some(label_name(method_name))
    _ => None
  }
}

///|
pub fn match_call_info(
  expr : @syntax.Expr,
) -> (String, Array[@syntax.Argument], @basic.Location)? {
  match unwrap_paren(expr) {
    @syntax.Apply(func~, args~, loc~, ..) =>
      match match_callable_name(func) {
        Some(name) => Some((name, list_to_array(args), loc))
        None => None
      }
    @syntax.DotApply(method_name~, args~, loc~, ..) =>
      Some((label_name(method_name), list_to_array(args), loc))
    _ => None
  }
}

///|
pub fn is_async_with_task_group_call(expr : @syntax.Expr) -> Bool {
  match unwrap_paren(expr) {
    @syntax.Ident(id=ident, ..) => {
      let name = longident_right_name(ident.name)
      match longident_pkg_name(ident.name) {
        Some(pkg) => pkg == "async" && name == "with_task_group"
        None => false
      }
    }
    @syntax.Field(
      record=@syntax.Ident(id=ident, ..),
      accessor=@syntax.Accessor::Label(label),
      ..
    ) =>
      label_name(label) == "with_task_group" &&
      longident_right_name(ident.name) == "async"
    _ => false
  }
}

///|
pub fn first_positional_arg(args : Array[@syntax.Argument]) -> @syntax.Expr? {
  for arg in args {
    match arg.kind {
      @syntax.ArgumentKind::Positional => return Some(arg.value)
      _ => ()
    }
  }
  None
}

///|
pub fn first_two_positional_args(
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
pub fn func_param_names(func : @syntax.Func) -> Array[String] {
  let params = list_to_array(func.parameters)
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
pub fn is_some_pattern(pat : @syntax.Pattern) -> Bool {
  match pat {
    @syntax.Pattern::Constr(constr~, args=Some(args), ..) => {
      if constructor_name(constr) != "Some" {
        return false
      }
      let args_array = list_to_array(args)
      args_array.length() == 1
    }
    _ => false
  }
}

///|
pub fn some_binder_name(pat : @syntax.Pattern) -> String? {
  match pat {
    @syntax.Pattern::Constr(constr~, args=Some(args), ..) => {
      if constructor_name(constr) != "Some" {
        return None
      }
      let args_array = list_to_array(args)
      if args_array.length() != 1 {
        return None
      }
      let arg = args_array[0]
      match arg.pat {
        @syntax.Pattern::Var(binder) => Some(binder.name)
        _ => None
      }
    }
    _ => None
  }
}

///|
pub fn is_none_pattern(pat : @syntax.Pattern) -> Bool {
  match pat {
    @syntax.Pattern::Constr(constr~, args=None, ..) =>
      constructor_name(constr) == "None"
    @syntax.Pattern::Constr(constr~, args=Some(args), ..) => {
      if constructor_name(constr) != "None" {
        return false
      }
      let args_array = list_to_array(args)
      args_array.length() == 0
    }
    _ => false
  }
}

///|
pub fn is_none_expr(expr : @syntax.Expr) -> Bool {
  match unwrap_paren(expr) {
    @syntax.Constr(constr={ name: { name: "None", .. }, .. }, ..) => true
    _ => false
  }
}

///|
pub fn is_discard_pattern(pat : @syntax.Pattern) -> Bool {
  match pat {
    @syntax.Pattern::Any(..) => true
    @syntax.Pattern::Var(binder) => binder.name == "_"
    @syntax.Pattern::Alias(pat=inner, alias_=binder, ..) =>
      binder.name == "_" || is_discard_pattern(inner)
    _ => false
  }
}

///|
pub fn match_constant_bool(expr : @syntax.Expr) -> Bool? {
  match unwrap_paren(expr) {
    @syntax.Constant(c=Bool(value), ..) => Some(value)
    _ => None
  }
}

///|
pub fn is_unit_expr(expr : @syntax.Expr) -> Bool {
  match unwrap_paren(expr) {
    @syntax.Unit(..) => true
    _ => false
  }
}

///|
pub fn is_trivial_expr(expr : @syntax.Expr) -> Bool {
  match unwrap_paren(expr) {
    @syntax.Ident(..) => true
    @syntax.Constant(..) => true
    _ => false
  }
}

///|
pub fn source_slice(source : String, loc : @basic.Location) -> String? {
  if source == "" {
    return None
  }
  let start = loc.start.cnum
  let end = loc.end.cnum
  if start < 0 || end < start || end > source.length() {
    return None
  }
  let view_result : Result[StringView, Error] = try? source[start:end]
  match view_result {
    Ok(view) => Some(view.to_string())
    Err(_) => None
  }
}

///|
pub fn location_key(loc : @basic.Location) -> String {
  "\{loc.start.cnum}-\{loc.end.cnum}"
}

///|
pub fn expr_source(source : String, expr : @syntax.Expr) -> String? {
  source_slice(source, expr.loc())
}

///|
pub fn pattern_source(source : String, pat : @syntax.Pattern) -> String? {
  source_slice(source, pat.loc())
}

///|
pub fn match_try_question(
  expr : @syntax.Expr,
) -> (@syntax.Expr, @basic.Location)? {
  match unwrap_paren(expr) {
    @syntax.TryOperator(kind=Question, body~, try_loc=_, loc~) =>
      Some((body, loc))
    _ => None
  }
}

///|
pub fn match_match_expr(
  expr : @syntax.Expr,
) -> (@syntax.Expr, @basic.Location)? {
  match unwrap_paren(expr) {
    @syntax.Match(expr=subject, cases=_, match_loc=_, loc~) =>
      Some((subject, loc))
    _ => None
  }
}
