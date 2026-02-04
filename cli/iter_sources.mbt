///|
#callsite(autofill(loc))
fn is_directory(path : String, loc~ : SourceLoc) -> Bool raise Error {
  @fs.is_dir(path) catch {
    err => fail("failed to check if \{path} is a directory: \{err}", loc~)
  }
}

///|
fn need_ignore(path : String) -> Bool {
  let ignore_list = [
    "target", "_build", ".git", ".mooncakes", ".github", ".moonagent", "rules",
  ]
  ignore_list.contains(path)
}

///|
fn strip_trailing_slash(path : String) -> String {
  if path.length() <= 1 || !path.has_suffix("/") {
    return path
  }
  let slice_result : Result[StringView, Error] = try? path[:path.length() - 1]
  match slice_result {
    Ok(view) => view.to_string()
    Err(_) => path
  }
}

///|
fn join_path(base : String, child : String) -> String {
  if base == "" {
    return child
  }
  if base.has_suffix("/") {
    return base + child
  }
  base + "/" + child
}

///|
fn join_rel(base : String, child : String) -> String {
  if base == "" || base == "." {
    return child
  }
  join_path(base, child)
}

///|
fn parent_dir(path : String) -> String? {
  let trimmed = strip_trailing_slash(path)
  if trimmed == "/" {
    return None
  }
  match trimmed.rev_find("/") {
    None => None
    Some(idx) =>
      if idx == 0 {
        Some("/")
      } else {
        let slice_result : Result[StringView, Error] = try? trimmed[:idx]
        match slice_result {
          Ok(view) => Some(view.to_string())
          Err(_) => None
        }
      }
  }
}

///|
fn find_module_root(start_dir : String) -> String? {
  let mut current = strip_trailing_slash(start_dir)
  if current == "" {
    current = "."
  }
  while true {
    let candidate = join_path(current, "moon.mod.json")
    if @fs.path_exists(candidate) {
      return Some(current)
    }
    match parent_dir(current) {
      Some(parent) => if parent == current { break } else { current = parent }
      None => break
    }
  }
  None
}

///|
fn get_mbt_path_set_from_base(
  base_fs : String,
  base_rel : String,
) -> Array[String] raise Error {
  let mbt_set = Array::new(capacity=20)
  let path_set = @fs.read_dir(base_fs) catch {
    err => fail("failed to read directory \{base_fs}: \{err}")
  }
  let path_set = {
    let q = @queue.new()
    for path in path_set {
      // ignore target directory
      if !need_ignore(path) {
        q.push((join_path(base_fs, path), join_rel(base_rel, path)))
      }
    } else {
      q
    }
  }
  while not(path_set.is_empty()) {
    let (fs_path, rel_path) = path_set.unsafe_pop()
    if (fs_path |> @fs.path_exists |> not) {
      println("invalid path construct by starlint internal: \{fs_path}")
    }
    if is_directory(fs_path) {
      let new_path_set = @fs.read_dir(fs_path) catch {
        err => fail("failed to read directory \{base_fs}: \{err}")
      }
      for new_path in new_path_set {
        path_set.push(
          (join_path(fs_path, new_path), join_rel(rel_path, new_path)),
        )
      }
    } else if fs_path.has_suffix(".mbt") {
      mbt_set.push(rel_path)
    }
  } else {
    return mbt_set
  }
}

///|
fn load_module_info(module_root : String) -> Json raise Error {
  let text = @fs.read_file_to_string(join_path(module_root, "moon.mod.json"))
  @json.parse(text)
}

///|
fn get_src_location(module_info : Json) -> String {
  if module_info is Object(module_info) &&
    module_info.get("source") is Some(String(src)) {
    return src
  } else {
    return "."
  }
}

///|
fn is_abs_path(path : String) -> Bool {
  path.has_prefix("/")
}

///|
fn resolve_path(base : String, path : String) -> String {
  if is_abs_path(path) {
    path
  } else if base == "" {
    path
  } else {
    join_path(base, path)
  }
}

///|
fn path_relative_to_root(path : String, root : String) -> String? {
  let trimmed_root = strip_trailing_slash(root)
  if path == trimmed_root {
    return Some("")
  }
  let prefix = trimmed_root + "/"
  if !path.has_prefix(prefix) {
    return None
  }
  let slice_result : Result[StringView, Error] = try? path[prefix.length():]
  match slice_result {
    Ok(view) => Some(view.to_string())
    Err(_) => None
  }
}

///|
fn strip_dot_slash(path : String) -> String {
  if !path.has_prefix("./") {
    return path
  }
  let slice_result : Result[StringView, Error] = try? path[2:]
  match slice_result {
    Ok(view) => view.to_string()
    Err(_) => path
  }
}
