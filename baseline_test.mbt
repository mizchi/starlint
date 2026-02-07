///|
test "complexity of simple function is 1" {
  let source =
    #|fn foo() -> Int {
    #|  42
    #|}
  let (impls, reports) = parse_string_for_lint(source, name="<test>")
  inspect(reports.length(), content="0")
  let result = compute_file_complexity(impls, source)
  inspect(result.length(), content="1")
  inspect(result[0].name, content="foo")
  inspect(result[0].complexity, content="1")
}

///|
test "complexity with if adds 1" {
  let source =
    #|fn foo(x : Int) -> Int {
    #|  if x > 0 { x } else { -x }
    #|}
  let (impls, reports) = parse_string_for_lint(source, name="<test>")
  inspect(reports.length(), content="0")
  let result = compute_file_complexity(impls, source)
  inspect(result[0].complexity, content="2")
}

///|
test "complexity with match" {
  let source =
    #|fn foo(x : Int) -> String {
    #|  match x {
    #|    0 => "zero"
    #|    1 => "one"
    #|    _ => "other"
    #|  }
    #|}
  let (impls, reports) = parse_string_for_lint(source, name="<test>")
  inspect(reports.length(), content="0")
  let result = compute_file_complexity(impls, source)
  // base 1 + (3 cases - 1) = 3
  inspect(result[0].complexity, content="3")
}

///|
test "complexity with loop and logical operators" {
  let source =
    #|fn foo(xs : Array[Int]) -> Int {
    #|  let mut sum = 0
    #|  for x in xs {
    #|    if x > 0 && x < 100 {
    #|      sum = sum + x
    #|    }
    #|  }
    #|  sum
    #|}
  let (impls, reports) = parse_string_for_lint(source, name="<test>")
  inspect(reports.length(), content="0")
  let result = compute_file_complexity(impls, source)
  // base 1 + for 1 + if 1 + && 1 = 4
  inspect(result[0].complexity, content="4")
}

///|
test "count_loc counts non-empty lines" {
  let source =
    #|fn foo() {
    #|
    #|  42
    #|
    #|}
  inspect(count_loc(source), content="3")
}

///|
test "count_loc empty string" {
  inspect(count_loc(""), content="0")
}

///|
test "baseline JSON round-trip" {
  let packages = Map::new()
  packages.set("test/pkg", PackageBaseline::{
    pub_fn_count: 2,
    pub_type_count: 1,
    pub_api_names: ["foo", "bar"],
    test_count: 3,
    loc: 100,
  })
  let files = Map::new()
  files.set("src/main.mbt", FileBaseline::{
    package_name: "test/pkg",
    loc: 50,
    functions: [FunctionComplexity::{ name: "foo", complexity: 3 }],
    complexity_avg: 3.0,
    complexity_max: 3,
  })
  let by_rule = Map::new()
  by_rule.set("prefer_pipeline", 2)
  let baseline = Baseline::{
    version: "1",
    packages,
    files,
    diagnostics: DiagnosticsSummary::{ total: 2, by_rule },
    summary: BaselineSummary::{
      total_files: 1,
      total_loc: 50,
      total_packages: 1,
      total_pub_apis: 2,
      total_tests: 3,
      total_diagnostics: 2,
      avg_complexity: 3.0,
      max_complexity: 3,
    },
  }
  let json_text = baseline.to_json()
  let parsed = Baseline::from_json(json_text)
  inspect(parsed.version, content="1")
  inspect(parsed.summary.total_files, content="1")
  inspect(parsed.summary.total_loc, content="50")
  inspect(parsed.summary.total_pub_apis, content="2")
  inspect(parsed.summary.total_tests, content="3")
  inspect(parsed.summary.total_diagnostics, content="2")
  inspect(parsed.summary.max_complexity, content="3")
  inspect(parsed.diagnostics.total, content="2")
  let pkg = parsed.packages.get("test/pkg")
  inspect(pkg is None, content="false")
  match pkg {
    Some(p) => {
      inspect(p.pub_fn_count, content="2")
      inspect(p.pub_type_count, content="1")
      inspect(p.test_count, content="3")
      inspect(p.loc, content="100")
      inspect(p.pub_api_names.length(), content="2")
    }
    None => fail("package not found")
  }
  let file = parsed.files.get("src/main.mbt")
  match file {
    Some(f) => {
      inspect(f.package_name, content="test/pkg")
      inspect(f.loc, content="50")
      inspect(f.functions.length(), content="1")
      inspect(f.functions[0].name, content="foo")
      inspect(f.functions[0].complexity, content="3")
      inspect(f.complexity_max, content="3")
    }
    None => fail("file not found")
  }
}
