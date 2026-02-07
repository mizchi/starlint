///|
priv struct ComplexityEnv {
  mut count : Int
}

///|
impl @syntax.IterVisitor for ComplexityEnv with visit_Expr(env, expr) {
  match expr {
    @syntax.If(..) => env.count += 1
    @syntax.Match(cases~, ..) => {
      let n = list_to_array(cases).length()
      if n > 1 {
        env.count += n - 1
      }
    }
    @syntax.For(..) => env.count += 1
    @syntax.ForEach(..) => env.count += 1
    @syntax.While(..) => env.count += 1
    @syntax.Loop(..) => env.count += 1
    @syntax.TryOperator(..) => env.count += 1
    @syntax.Infix(op={ name: Ident(name~), .. }, ..) =>
      if name == "&&" || name == "||" {
        env.count += 1
      }
    _ => ()
  }
  env.base().visit_Expr(expr)
}

///|
pub fn compute_complexity(body : @syntax.Expr) -> Int {
  let env = ComplexityEnv::{ count: 1 }
  env.visit_Expr(body)
  env.count
}

///|
pub(all) struct FunctionComplexity {
  name : String
  complexity : Int
} derive(Eq, Show)

///|
pub fn compute_file_complexity(
  impls : @syntax.Impls,
  source : String,
) -> Array[FunctionComplexity] {
  ignore(source)
  let results = Array::new(capacity=8)
  for impl_ in impls {
    match impl_ {
      @syntax.Impl::TopFuncDef(fun_decl~, decl_body~, loc=_) => {
        let name = format_fun_decl_name(fun_decl)
        match decl_body {
          @syntax.DeclBody::DeclBody(local_types=_, expr~) =>
            results.push(FunctionComplexity::{
              name,
              complexity: compute_complexity(expr),
            })
          _ => ()
        }
      }
      @syntax.Impl::TopImpl(self_ty~, method_name~, body~, ..) => {
        let name = format_impl_method_name(self_ty, method_name)
        match body {
          @syntax.DeclBody::DeclBody(local_types=_, expr~) =>
            results.push(FunctionComplexity::{
              name,
              complexity: compute_complexity(expr),
            })
          _ => ()
        }
      }
      @syntax.Impl::TopView(view_func_name~, body~, ..) => {
        let name = view_func_name.name
        results.push(FunctionComplexity::{
          name,
          complexity: compute_complexity(body),
        })
      }
      _ => ()
    }
  } else {
    results
  }
}

///|
pub fn count_loc(source : String) -> Int {
  let mut count = 0
  for part in source.split("\n") {
    let line = part.to_string().trim().to_string()
    if line != "" {
      count += 1
    }
  }
  count
}

///|
fn format_fun_decl_name(fun_decl : @syntax.FunDecl) -> String {
  let base = fun_decl.name.name
  match fun_decl.type_name {
    Some(type_name) => "\{type_name_right_name(type_name)}::\{base}"
    None => base
  }
}

///|
fn format_impl_method_name(
  self_ty : @syntax.Type?,
  method_name : @syntax.Binder,
) -> String {
  let base = method_name.name
  match self_ty {
    Some(ty) =>
      match type_short_name(ty) {
        Some(type_name) => "\{type_name}::\{base}"
        None => base
      }
    None => base
  }
}

///|
fn type_short_name(ty : @syntax.Type) -> String? {
  match ty {
    @syntax.Type::Name(constr_id~, ..) =>
      constr_id |> constr_id_right_name |> Some
    @syntax.Type::Object(constr_id) => constr_id |> constr_id_right_name |> Some
    _ => None
  }
}
