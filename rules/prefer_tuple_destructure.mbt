///|
let prefer_tuple_destructure_rule_id : String = "prefer_tuple_destructure"

///|
let prefer_tuple_destructure_description : String = "Prefer tuple destructuring over multiple tuple field bindings."

///|
priv struct PreferTupleDestructureEnv {
  diags : Array[@moonlint.Diagnostic]
  source : String
  skip_locs : Map[String, Bool]
}

///|
priv struct TupleLetInfo {
  loc : @basic.Location
  name : String
  index : Int
}

///|
fn tuple_field_info(expr : @syntax.Expr) -> (@syntax.Expr, Int)? {
  match @moonlint.unwrap_paren(expr) {
    @syntax.Field(
      record~,
      accessor=@syntax.Accessor::Index(tuple_index~, loc=_),
      ..
    ) => Some((record, tuple_index))
    _ => None
  }
}

///|
fn collect_tuple_let_chain(
  env : PreferTupleDestructureEnv,
  expr : @syntax.Expr,
) -> (@basic.Location, String, Array[TupleLetInfo], @syntax.Expr)? {
  let mut current = expr
  let mut outer_loc : @basic.Location? = None
  let mut record_src : String? = None
  let lets = Array::new(capacity=4)
  while true {
    match current {
      @syntax.Let(pattern~, expr=bound, body~, loc~) =>
        match pattern {
          @syntax.Pattern::Var(binder) if binder.name != "_" =>
            match tuple_field_info(bound) {
              Some((record, index)) => {
                let rec_src = match @moonlint.expr_source(env.source, record) {
                  Some(src) => src
                  None => return None
                }
                match record_src {
                  None => record_src = Some(rec_src)
                  Some(prev) if prev == rec_src => ()
                  _ => return None
                }
                if outer_loc is None {
                  outer_loc = Some(loc)
                }
                lets.push(TupleLetInfo::{ loc, name: binder.name, index })
                current = body
              }
              None => break
            }
          _ => break
        }
      _ => break
    }
  }
  if lets.length() >= 2 {
    match (outer_loc, record_src) {
      (Some(loc), Some(record_src)) => Some((loc, record_src, lets, current))
      _ => None
    }
  } else {
    None
  }
}

///|
fn indices_are_consecutive(lets : Array[TupleLetInfo]) -> Bool {
  let mut expected = 0
  for item in lets {
    if item.index != expected {
      return false
    }
    expected = expected + 1
  }
  true
}

///|
fn all_names_unique(lets : Array[TupleLetInfo]) -> Bool {
  let seen = Map::new()
  for item in lets {
    if seen.get(item.name) is Some(_) {
      return false
    }
    seen.set(item.name, true)
  }
  true
}

///|
fn tuple_pattern_src(lets : Array[TupleLetInfo]) -> String {
  let names = Array::new(capacity=lets.length())
  for item in lets {
    names.push(item.name)
  }
  let joined = names.join(", ")
  "(\{joined})"
}

///|
fn line_indent(source : String, loc : @basic.Location) -> String {
  if source == "" {
    return ""
  }
  let start = loc.start.cnum
  if start <= 0 || start > source.length() {
    return ""
  }
  let prefix_result : Result[StringView, Error] = try? source[:start]
  match prefix_result {
    Ok(prefix) => {
      let line_start = match prefix.rev_find("\n") {
        Some(idx) => idx + 1
        None => 0
      }
      let indent_result : Result[StringView, Error] = try? source[line_start:start]
      match indent_result {
        Ok(view) => view.to_string()
        Err(_) => ""
      }
    }
    Err(_) => ""
  }
}

///|
fn push_prefer_tuple_destructure_diag(
  env : PreferTupleDestructureEnv,
  loc : @basic.Location,
  record_src : String,
  lets : Array[TupleLetInfo],
  body : @syntax.Expr,
) -> Unit {
  let message = "Tuple fields can be destructured in one let binding."
  let detail =
    #|let a = t.0
    #|let b = t.1
  let suggestion = "let \{tuple_pattern_src(lets)} = \{record_src}"
  let fix = match @moonlint.expr_source(env.source, body) {
    Some(body_src) => {
      let indent = line_indent(env.source, loc)
      let replacement = "let \{tuple_pattern_src(lets)} = \{record_src}\n\{indent}\{body_src}"
      Some(@moonlint.Fix::new(range=loc, replacement~))
    }
    None => None
  }
  let diag = match fix {
    Some(fix) =>
      @moonlint.Diagnostic::new(
        rule_id=prefer_tuple_destructure_rule_id,
        loc~,
        message~,
        detail~,
        suggestion~,
        fix~,
      )
    None =>
      @moonlint.Diagnostic::new(
        rule_id=prefer_tuple_destructure_rule_id,
        loc~,
        message~,
        detail~,
        suggestion~,
      )
  }
  env.diags.push(diag)
}

///|
impl @syntax.IterVisitor for PreferTupleDestructureEnv with visit_Expr(
  env,
  expr,
) {
  match expr {
    @syntax.Let(loc~, ..) =>
      if env.skip_locs.get(@moonlint.location_key(loc)) is None {
        match collect_tuple_let_chain(env, expr) {
          Some((loc, record_src, lets, body)) =>
            if indices_are_consecutive(lets) && all_names_unique(lets) {
              for item in lets {
                env.skip_locs.set(@moonlint.location_key(item.loc), true)
              }
              push_prefer_tuple_destructure_diag(
                env, loc, record_src, lets, body,
              )
            }
          None => ()
        }
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
fn prefer_tuple_destructure_rule() -> @moonlint.Rule {
  @moonlint.Rule::new(
    id=prefer_tuple_destructure_rule_id,
    description=prefer_tuple_destructure_description,
    tags=["fp"],
    enabled_by_default=false,
    run=input => {
      let env = PreferTupleDestructureEnv::{
        diags: Array::new(capacity=8),
        source: input.source,
        skip_locs: Map::new(),
      }
      for impl_ in input.impls {
        env.visit_Impl(impl_)
      } else {
        env.diags
      }
    },
  )
}
