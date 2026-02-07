///|
pub struct WasiVFS {}

///|
pub fn WasiVFS::new() -> WasiVFS {
  WasiVFS::{  }
}

///|
pub impl VFS for WasiVFS with read_string(self, path : String) -> String raise Error {
  ignore(self)
  @fs.read_file_to_string(path)
}

///|
pub impl VFS for WasiVFS with write_string(
  self,
  path : String,
  content : String,
) -> Unit raise Error {
  ignore(self)
  @fs.write_string_to_file(path, content)
}

///|
pub impl VFS for WasiVFS with path_exists(self, path : String) -> Bool {
  ignore(self)
  @fs.path_exists(path)
}

///|
pub impl VFS for WasiVFS with read_dir(self, path : String) -> Array[String] raise Error {
  ignore(self)
  @fs.read_dir(path)
}

///|
pub impl VFS for WasiVFS with is_dir(self, path : String) -> Bool raise Error {
  ignore(self)
  @fs.is_dir(path)
}
