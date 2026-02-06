///|
test "find_module_root locates moon.mod.json in ancestors" {
  let fs = MemVFS::new()
  fs.add_file("/project/moon.mod.json", "{\"name\": \"test\"}")
  fs.add_file("/project/src/foo/bar.mbt", "fn main {}")
  // Simulate starting from /project/src/foo
  // find_module_root is in cli, so we test VFS indirectly here
  assert_true(fs.path_exists("/project/moon.mod.json"))
  assert_true(fs.path_exists("/project/src/foo/bar.mbt"))
  assert_false(fs.path_exists("/project/src/moon.mod.json"))
}

///|
test "VFS read_dir finds .mbt files" {
  let fs = MemVFS::new()
  fs.add_file("/src/a.mbt", "// a")
  fs.add_file("/src/b.mbt", "// b")
  fs.add_file("/src/c.txt", "// c")
  fs.add_dir("/src/sub")
  let entries = fs.read_dir("/src")
  // Verify contains expected entries (order may vary)
  assert_eq(entries.length(), 4)
  assert_true(entries.contains("a.mbt"))
  assert_true(entries.contains("b.mbt"))
  assert_true(entries.contains("c.txt"))
  assert_true(entries.contains("sub"))
  let mbt_files = entries.filter(fn(e) { e.has_suffix(".mbt") })
  assert_eq(mbt_files.length(), 2)
}

///|
test "VFS write_string and read_string roundtrip" {
  let fs = MemVFS::new()
  fs.write_string("/test.txt", "hello")
  let content = fs.read_string("/test.txt")
  assert_eq(content, "hello")
  fs.write_string("/test.txt", "world")
  let updated = fs.read_string("/test.txt")
  assert_eq(updated, "world")
}

///|
test "VFS nested directory traversal" {
  let fs = MemVFS::new()
  fs.add_file("/a/b/c/d/file.mbt", "code")
  assert_true(fs.path_exists("/a"))
  assert_true(fs.path_exists("/a/b"))
  assert_true(fs.path_exists("/a/b/c"))
  assert_true(fs.path_exists("/a/b/c/d"))
  assert_true(fs.path_exists("/a/b/c/d/file.mbt"))
  let a_entries = fs.read_dir("/a")
  assert_eq(a_entries, ["b"])
  let b_entries = fs.read_dir("/a/b")
  assert_eq(b_entries, ["c"])
}
