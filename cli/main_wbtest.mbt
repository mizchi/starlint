///|
test "parse_compare_option: long option" {
  let actual = parse_compare_option(["--compare", "baseline.json"][:])
  inspect(actual, content="baseline.json")
}

///|
test "parse_compare_option: short option" {
  let actual = parse_compare_option(["-c", "path/to/baseline.json"][:])
  inspect(actual, content="path/to/baseline.json")
}

///|
test "parse_compare_option: no option" {
  let actual = parse_compare_option(["foo.mbt"][:])
  inspect(actual, content="")
}

///|
test "parse_compare_option: missing value" {
  let actual = parse_compare_option(["--compare"][:])
  inspect(actual, content="")
}

///|
test "parse_meta_option: long help" {
  let actual = parse_meta_option(["--help"][:])
  inspect(actual, content="help")
}

///|
test "parse_meta_option: short help" {
  let actual = parse_meta_option(["-h"][:])
  inspect(actual, content="help")
}

///|
test "parse_meta_option: long version" {
  let actual = parse_meta_option(["--version"][:])
  inspect(actual, content="version")
}

///|
test "parse_meta_option: short version" {
  let actual = parse_meta_option(["-v"][:])
  inspect(actual, content="version")
}

///|
test "parse_meta_option: first hit wins" {
  let actual = parse_meta_option(["-v", "--help"][:])
  inspect(actual, content="version")
}

///|
test "parse_meta_option: no option" {
  let actual = parse_meta_option(["foo.mbt"][:])
  inspect(actual, content="")
}

///|
test "analyze_compare_path: default latest path" {
  let fs = @vfs.MemVFS::new()
  fs.write_string("/repo/.starlint/latest.json", "{}")
  let actual = analyze_compare_path(fs, "/repo", "")
  inspect(actual, content="/repo/.starlint/latest.json")
}

///|
test "analyze_compare_path: default current hash path" {
  let fs = @vfs.MemVFS::new()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string("/repo/.git/refs/heads/main", "abc123\n")
  fs.write_string("/repo/.starlint/abc123.json", "{}")
  let actual = analyze_compare_path(fs, "/repo", "")
  inspect(actual, content="/repo/.starlint/abc123.json")
}

///|
test "analyze_compare_path: default fallback latest path" {
  let fs = @vfs.MemVFS::new()
  let actual = analyze_compare_path(fs, "/repo", "")
  inspect(actual, content="/repo/.starlint/latest.json")
}

///|
test "analyze_compare_path: relative path" {
  let fs = @vfs.MemVFS::new()
  let actual = analyze_compare_path(fs, "/repo", "tmp/base.json")
  inspect(actual, content="/repo/tmp/base.json")
}

///|
test "analyze_compare_path: absolute path" {
  let fs = @vfs.MemVFS::new()
  let actual = analyze_compare_path(fs, "/repo", "/tmp/base.json")
  inspect(actual, content="/tmp/base.json")
}
