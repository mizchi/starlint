///|
pub(open) trait VFS {
  fn read_string(Self, path : String) -> String raise Error
  fn write_string(Self, path : String, content : String) -> Unit raise Error
  fn path_exists(Self, path : String) -> Bool
  fn read_dir(Self, path : String) -> Array[String] raise Error
  fn is_dir(Self, path : String) -> Bool raise Error
}
