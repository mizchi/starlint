# FP candidate fixtures (draft)

These are minimal input/expected pairs to validate applicability before
implementing rules. They are not wired to tests yet.

## prefer_eta_reduce
input:
```mbt
fn main {
  let f1 = fn(x){ g(x) }
  let f2 = (x) => g(x)
  let ys = xs.map(x => h(x))
}
```
expected:
```mbt
fn main {
  let f1 = g
  let f2 = g
  let ys = xs.map(h)
}
```

## prefer_tuple_destructure
input:
```mbt
fn main {
  let a = t.0
  let b = t.1
  let sum = a + b
}
```
expected:
```mbt
fn main {
  let (a, b) = t
  let sum = a + b
}
```

## avoid_unused_binding
input:
```mbt
fn main {
  let x = side_effect()
  let y = 1
  y + 1
}
```
expected:
```mbt
fn main {
  let _ = side_effect()
  let y = 1
  y + 1
}
```

## prefer_expression_over_return
input:
```mbt
fn f() {
  return foo()
}
```
expected:
```mbt
fn f() {
  foo()
}
```

## prefer_match_over_if_chain
input:
```mbt
fn f(opt) {
  if opt is Some(v) { v } else { 0 }
}
```
expected:
```mbt
fn f(opt) {
  match opt {
    Some(v) => v
    None => 0
  }
}
```

## avoid_side_effect_in_map
input:
```mbt
fn main {
  let mut sum = 0
  xs.map(x => { sum = sum + x })
}
```
expected:
```mbt
fn main {
  let mut sum = 0
  xs.iter().each(x => { sum = sum + x })
}
```

## prefer_option_filter
input:
```mbt
fn f(opt) {
  match opt {
    Some(v) => if p(v) { Some(v) } else { None }
    None => None
  }
}
```
expected:
```mbt
fn f(opt) {
  opt.filter(p)
}
```

## prefer_option_bind (type-dependent)
input:
```mbt
fn f(opt) {
  match opt {
    Some(v) => g(v)
    None => None
  }
}
```
expected:
```mbt
fn f(opt) {
  opt.bind(g)
}
```

## prefer_result_map_err
input:
```mbt
fn f(res) {
  match res {
    Ok(v) => Ok(v)
    Err(e) => Err(g(e))
  }
}
```
expected:
```mbt
fn f(res) {
  res.map_err(g)
}
```

## prefer_result_bind (type-dependent)
input:
```mbt
fn f(res) {
  match res {
    Ok(v) => g(v)
    Err(e) => Err(e)
  }
}
```
expected:
```mbt
fn f(res) {
  res.bind(g)
}
```
