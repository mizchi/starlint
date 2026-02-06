///|
pub(open) trait VFS {
  read_string(Self, path : String) -> String raise Error
  write_string(Self, path : String, content : String) -> Unit raise Error
  path_exists(Self, path : String) -> Bool
  read_dir(Self, path : String) -> Array[String] raise Error
  is_dir(Self, path : String) -> Bool raise Error
}
