///|
let prefer_test_mbt_for_multi_wbtest_rule_id : String = "prefer_test_mbt_for_multi_wbtest"

///|
let prefer_test_mbt_for_multi_wbtest_description : String = "When a package has multiple _wbtest.mbt files and no _test.mbt, prefer consolidating into _test.mbt."

///|
fn wbtest_rule_string_has_suffix(value : String, suffix : String) -> Bool {
  if value.length() < suffix.length() {
    return false
  }
  let start = value.length() - suffix.length()
  let view_result : Result[StringView, Error] = try? value[start:]
  match view_result {
    Ok(view) => view == suffix
    Err(_) => false
  }
}

///|
fn parent_dir(path : String) -> String {
  match path.rev_find("/") {
    None => ""
    Some(idx) => {
      let view_result : Result[StringView, Error] = try? path[:idx]
      match view_result {
        Ok(view) => view.to_string()
        Err(_) => ""
      }
    }
  }
}

///|
fn is_wbtest_file(path : String) -> Bool {
  wbtest_rule_string_has_suffix(path, "_wbtest.mbt")
}

///|
fn is_blackbox_test_file(path : String) -> Bool {
  (wbtest_rule_string_has_suffix(path, "_test.mbt") && !is_wbtest_file(path)) ||
  wbtest_rule_string_has_suffix(path, "_tests.mbt")
}

///|
fn package_files_for_input(input : @starlint.LintInput) -> Array[String] {
  if input.package_filenames.is_empty() {
    [input.filename]
  } else {
    input.package_filenames
  }
}

///|
fn prefer_test_mbt_for_multi_wbtest_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=prefer_test_mbt_for_multi_wbtest_rule_id,
    description=prefer_test_mbt_for_multi_wbtest_description,
    tags=["module", "test"],
    enabled_by_default=false,
    run=input => {
      if !is_wbtest_file(input.filename) {
        return []
      }
      let package_dir = parent_dir(input.filename)
      let mut wbtest_count = 0
      let mut blackbox_count = 0
      for file in package_files_for_input(input) {
        if parent_dir(file) != package_dir {
          continue
        }
        if is_wbtest_file(file) {
          wbtest_count += 1
        }
        if is_blackbox_test_file(file) {
          blackbox_count += 1
        }
      }
      if wbtest_count < 2 || blackbox_count > 0 {
        return []
      }
      let package_label = if package_dir == "" { "(root)" } else { package_dir }
      let pos = @basic.Position::{
        fname: input.filename,
        lnum: 1,
        bol: 0,
        cnum: 0,
      }
      let loc = @basic.Location::{ start: pos, end: pos }
      let suggestion =
        #|Add or consolidate tests into a *_test.mbt file in this package.
      [
        @starlint.Diagnostic::new(
          rule_id=prefer_test_mbt_for_multi_wbtest_rule_id,
          loc~,
          message="Package '\{package_label}' has \{wbtest_count} *_wbtest.mbt files and no *_test.mbt. Prefer consolidating into *_test.mbt.",
          suggestion~,
        ),
      ]
    },
  )
}
