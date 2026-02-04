///|
fn parse_int_or(default_value : Int, value : String) -> Int {
  try @strconv.parse_int(value[:], base=10) catch {
    _ => default_value
  } noraise {
    parsed => parsed
  }
}

///|
fn parse_uint_or(default_value : UInt, value : String) -> UInt {
  try @strconv.parse_uint(value[:], base=10) catch {
    _ => default_value
  } noraise {
    parsed => parsed
  }
}

///|
fn bench_size() -> Int {
  let default_size = 100000
  match @sys.get_env_var("MOONLINT_BENCH_SIZE") {
    Some(value) => parse_int_or(default_size, value)
    None => default_size
  }
}

///|
fn bench_count() -> UInt {
  let default_count : UInt = 3
  match @sys.get_env_var("MOONLINT_BENCH_COUNT") {
    Some(value) => parse_uint_or(default_count, value)
    None => default_count
  }
}

///|
fn build_array(n : Int) -> Array[Int] {
  let xs = Array::new(capacity=n)
  for i in 0..<n {
    xs.push(i)
  }
  xs
}

///|
struct Box {
  mut x : Int
}

///|
fn Box::inc(self : Box) -> Unit {
  self.x += 1
}

///|
fn Box::mul(self : Box) -> Unit {
  self.x *= 2
}

///|
fn bench_loop_vs_map_filter(bench : @bench.T, size : Int, count : UInt) -> Unit {
  let xs = build_array(size)
  bench.bench(
    fn() {
      let out : Array[Int] = []
      for x in xs {
        if x % 2 == 0 {
          out.push(x + 1)
        }
      }
      bench.keep(out.length())
    },
    name="loop_collect_filter_map",
    count~,
  )
  bench.bench(
    fn() {
      let out = xs.filter(x => x % 2 == 0).map(x => x + 1)
      bench.keep(out.length())
    },
    name="map_filter_chain",
    count~,
  )
}

///|
fn bench_prefer_pipeline_vs_nested(
  bench : @bench.T,
  size : Int,
  count : UInt,
) -> Unit {
  let xs = build_array(size)
  fn f(x : Int) -> Int {
    x + 1
  }

  fn g(x : Int) -> Int {
    x * 2
  }

  fn h(x : Int) -> Int {
    x - 3
  }

  bench.bench(
    fn() {
      let mut sum = 0
      for x in xs {
        sum += x |> h |> g |> f
      }
      bench.keep(sum)
    },
    name="nested_calls",
    count~,
  )
  bench.bench(
    fn() {
      let mut sum = 0
      for x in xs {
        sum += x |> h |> g |> f
      }
      bench.keep(sum)
    },
    name="prefer_pipeline_calls",
    count~,
  )
}

///|
fn bench_dotdot_chain(bench : @bench.T, size : Int, count : UInt) -> Unit {
  bench.bench(
    fn() {
      let mut acc = 0
      for _ in 0..<size {
        let b = Box::{ x: 1 }
        b.inc()
        b.mul()
        acc += b.x
      }
      bench.keep(acc)
    },
    name="statement_chain",
    count~,
  )
  bench.bench(
    fn() {
      let mut acc = 0
      for _ in 0..<size {
        let b = Box::{ x: 1 }
        b..inc()..mul()
        acc += b.x
      }
      bench.keep(acc)
    },
    name="dotdot_chain",
    count~,
  )
}

///|
fn bench_view_vs_copy(bench : @bench.T, size : Int, count : UInt) -> Unit {
  let s = "a".repeat(size)
  let xs = build_array(size)
  let half = size / 2
  bench.bench(
    fn() {
      let _copy = (try! s[0:half]).to_string()
      bench.keep(_copy.length())
    },
    name="string_copy",
    count~,
  )
  bench.bench(
    fn() {
      let _view = try! s[0:half]
      bench.keep(_view.length())
    },
    name="string_view",
    count~,
  )
  bench.bench(
    fn() {
      let _copy = xs[0:half].to_array()
      bench.keep(_copy.length())
    },
    name="array_copy",
    count~,
  )
  bench.bench(
    fn() {
      let _view = xs[0:half]
      bench.keep(_view.length())
    },
    name="array_view",
    count~,
  )
}

///|
test (bench : @bench.T) {
  let size = bench_size()
  let count = bench_count()
  bench_loop_vs_map_filter(bench, size, count)
  bench_prefer_pipeline_vs_nested(bench, size, count)
  bench_dotdot_chain(bench, size / 10, count)
  bench_view_vs_copy(bench, size, count)
}
