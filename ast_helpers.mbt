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
