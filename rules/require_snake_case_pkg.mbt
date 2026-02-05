///|
let require_snake_case_pkg_rule_id : String = "require_snake_case_pkg"

///|
let require_snake_case_pkg_description : String = "Package directory names and file names must be snake_case."

///|
fn is_snake_case(name : String) -> Bool {
  if name.length() == 0 {
    return false
  }
  let mut first = true
  let mut prev_underscore = false
  let mut last_char = '_'
  for c in name {
    if first {
      first = false
      if !(c >= 'a' && c <= 'z') {
        return false
      }
      last_char = c
      continue
    }
    let valid = (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_'
    if !valid {
      return false
    }
    if c == '_' && prev_underscore {
      return false
    }
    prev_underscore = c == '_'
    last_char = c
  }
  last_char != '_'
}

///|
fn extract_pkg_dir_name(filename : String) -> String? {
  match filename.rev_find("/") {
    None => None
    Some(idx) => {
      let dir_result : Result[StringView, Error] = try? filename[:idx]
      match dir_result {
        Ok(view) => {
          let dir = view.to_string()
          match dir.rev_find("/") {
            None => Some(dir)
            Some(idx2) => {
              let seg_result : Result[StringView, Error] = try? dir[idx2 + 1:]
              match seg_result {
                Ok(v) => Some(v.to_string())
                Err(_) => None
              }
            }
          }
        }
        Err(_) => None
      }
    }
  }
}

///|
fn extract_file_stem(filename : String) -> String? {
  // Get basename (after last /)
  let base = match filename.rev_find("/") {
    None => filename
    Some(idx) => {
      let r : Result[StringView, Error] = try? filename[idx + 1:]
      match r {
        Ok(v) => v.to_string()
        Err(_) => return None
      }
    }
  }
  // Remove .mbt extension
  if !base.has_suffix(".mbt") {
    return None
  }
  let r : Result[StringView, Error] = try? base[:base.length() - 4]
  match r {
    Ok(v) => {
      let stem = v.to_string()
      if stem.length() == 0 {
        None
      } else {
        Some(stem)
      }
    }
    Err(_) => None
  }
}

///|
fn require_snake_case_pkg_rule() -> @starlint.Rule {
  @starlint.Rule::new(
    id=require_snake_case_pkg_rule_id,
    description=require_snake_case_pkg_description,
    tags=["module"],
    enabled_by_default=false,
    run=input => {
      let diags = Array::new(capacity=2)
      let pos = @basic.Position::{
        fname: input.filename,
        lnum: 1,
        bol: 0,
        cnum: 0,
      }
      let loc = @basic.Location::{ start: pos, end: pos }
      match extract_pkg_dir_name(input.filename) {
        Some(pkg_name) =>
          if !is_snake_case(pkg_name) {
            let detail =
              #|myPackage/foo.mbt
            let suggestion =
              #|my_package/foo.mbt
            diags.push(
              @starlint.Diagnostic::new(
                rule_id=require_snake_case_pkg_rule_id,
                loc~,
                message="Package directory name '\{pkg_name}' is not snake_case.",
                detail~,
                suggestion~,
              ),
            )
          }
        _ => ()
      }
      match extract_file_stem(input.filename) {
        Some(stem) =>
          if !is_snake_case(stem) {
            let detail =
              #|myFile.mbt
            let suggestion =
              #|my_file.mbt
            diags.push(
              @starlint.Diagnostic::new(
                rule_id=require_snake_case_pkg_rule_id,
                loc~,
                message="File name '\{stem}.mbt' is not snake_case.",
                detail~,
                suggestion~,
              ),
            )
          }
        _ => ()
      }
      diags
    },
  )
}
