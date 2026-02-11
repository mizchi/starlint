///|
pub fn keep_bench_imports_used(
  source : String,
  name : String,
  path : String,
) -> (@syntax.Impls, String, String?, Array[@starlint.Rule]) raise Error {
  let (impls, _) = @starlint.parse_string_for_lint(
    source,
    name~,
    parser=MoonYacc,
  )
  let file_content = @fs.read_file_to_string(path)
  let env = @sys.get_env_var("STARLINT_BENCH_UNUSED")
  let rules = @lint.rules()
  (impls, file_content, env, rules)
}
