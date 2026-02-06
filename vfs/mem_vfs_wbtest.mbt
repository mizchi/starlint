///|
test "MemVFS read_string returns content" {
  let fs = MemVFS::new()
  fs.add_file("/foo/bar.txt", "hello world")
  let content = fs.read_string("/foo/bar.txt")
  assert_eq(content, "hello world")
}

///|
test "MemVFS read_string raises on missing file" {
  let fs = MemVFS::new()
  let result : Result[String, Error] = try? fs.read_string("/missing.txt")
  match result {
    Err(_) => ()
    Ok(_) => fail("expected error")
  }
}

///|
test "MemVFS write_string creates file" {
  let fs = MemVFS::new()
  fs.write_string("/new.txt", "content")
  let content = fs.read_string("/new.txt")
  assert_eq(content, "content")
}

///|
test "MemVFS path_exists returns true for file" {
  let fs = MemVFS::new()
  fs.add_file("/exists.txt", "data")
  assert_true(fs.path_exists("/exists.txt"))
  assert_false(fs.path_exists("/not_exists.txt"))
}

///|
test "MemVFS path_exists returns true for dir" {
  let fs = MemVFS::new()
  fs.add_dir("/mydir")
  assert_true(fs.path_exists("/mydir"))
}

///|
test "MemVFS read_dir lists entries" {
  let fs = MemVFS::new()
  fs.add_file("/root/a.txt", "a")
  fs.add_file("/root/b.txt", "b")
  fs.add_dir("/root/subdir")
  let entries = fs.read_dir("/root")
  entries.sort_by(fn(a, b) { a.compare(b) })
  assert_eq(entries, ["a.txt", "b.txt", "subdir"])
}

///|
test "MemVFS is_dir returns true for dir" {
  let fs = MemVFS::new()
  fs.add_file("/file.txt", "x")
  fs.add_dir("/folder")
  assert_false(fs.is_dir("/file.txt"))
  assert_true(fs.is_dir("/folder"))
}

///|
test "MemVFS ensure_parent_dirs creates ancestors" {
  let fs = MemVFS::new()
  fs.add_file("/a/b/c/file.txt", "x")
  assert_true(fs.path_exists("/a"))
  assert_true(fs.path_exists("/a/b"))
  assert_true(fs.path_exists("/a/b/c"))
}
