///|
pub struct MemVFS {
  files : Map[String, String]
  dirs : Map[String, Bool]
}

///|
pub fn MemVFS::new() -> MemVFS {
  MemVFS::{ files: {}, dirs: {} }
}

///|
fn MemVFS::ensure_parent_dirs(self : MemVFS, path : String) -> Unit {
  let mut current = path
  while true {
    match current.rev_find("/") {
      None => break
      Some(idx) =>
        if idx == 0 {
          self.dirs["/"] = true
          break
        } else {
          let view = current[:idx]
          let parent = view.to_string()
          if self.dirs.contains(parent) {
            break
          }
          self.dirs[parent] = true
          current = parent
        }
    }
  }
}

///|
pub fn MemVFS::add_file(self : MemVFS, path : String, content : String) -> Unit {
  self.files[path] = content
  self.ensure_parent_dirs(path)
}

///|
pub fn MemVFS::add_dir(self : MemVFS, path : String) -> Unit {
  self.dirs[path] = true
  self.ensure_parent_dirs(path)
}

///|
pub impl VFS for MemVFS with read_string(self, path : String) -> String raise Error {
  match self.files.get(path) {
    Some(content) => content
    None => raise FileNotFoundError(path)
  }
}

///|
pub impl VFS for MemVFS with write_string(self, path : String, content : String) -> Unit raise Error {
  self.files[path] = content
  self.ensure_parent_dirs(path)
}

///|
pub impl VFS for MemVFS with path_exists(self, path : String) -> Bool {
  self.files.contains(path) || self.dirs.contains(path)
}

///|
pub impl VFS for MemVFS with read_dir(self, path : String) -> Array[String] raise Error {
  let normalized = if path.has_suffix("/") {
    path[:path.length() - 1].to_string()
  } else {
    path
  }
  if !self.dirs.contains(normalized) && !self.files.contains(normalized) {
    raise FileNotFoundError(normalized)
  }
  let prefix = if normalized == "" { "" } else { normalized + "/" }
  let prefix_len = prefix.length()
  let seen : Map[String, Bool] = {}
  for file_path, _ in self.files {
    if file_path.has_prefix(prefix) {
      let rest = file_path[prefix_len:]
      let rest_str = rest.to_string()
      match rest_str.find("/") {
        Some(idx) => {
          let name = rest_str[:idx]
          seen[name.to_string()] = true
        }
        None => seen[rest_str] = true
      }
    }
  }
  for dir_path, _ in self.dirs {
    if dir_path.has_prefix(prefix) && dir_path.length() > prefix_len {
      let rest = dir_path[prefix_len:]
      let rest_str = rest.to_string()
      match rest_str.find("/") {
        Some(idx) => {
          let name = rest_str[:idx]
          seen[name.to_string()] = true
        }
        None => seen[rest_str] = true
      }
    }
  }
  let result = []
  for name, _ in seen {
    result.push(name)
  } nobreak {
    result
  }
}

///|
pub impl VFS for MemVFS with is_dir(self, path : String) -> Bool raise Error {
  self.dirs.contains(path)
}

///|
pub suberror FileNotFoundError {
  FileNotFoundError(String)
}

///|
impl Show for FileNotFoundError with output(self, logger) -> Unit {
  let FileNotFoundError(path) = self
  logger.write_string("FileNotFoundError: ")
  logger.write_string(path)
}
