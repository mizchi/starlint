///|
test "resolve_baseline_output_rel_path: clean hash" {
  let actual = resolve_baseline_output_rel_path(
    Some("0123456789abcdef"),
    GitDirtyStatus::Clean,
  )
  inspect(actual, content=".starlint/0123456789abcdef.json")
}

///|
test "resolve_baseline_output_rel_path: dirty uses latest" {
  let actual = resolve_baseline_output_rel_path(
    Some("0123456789abcdef"),
    GitDirtyStatus::Dirty,
  )
  inspect(actual, content=".starlint/latest.json")
}

///|
test "baseline_output_warning: dirty" {
  let actual = baseline_output_warning(
    Some("0123456789abcdef"),
    GitDirtyStatus::Dirty,
  )
  inspect(
    actual,
    content="Some(\"warning: git worktree is dirty; baseline is saved to .starlint/latest.json\")",
  )
}

///|
test "baseline_output_warning: clean with hash has no warning" {
  let actual = baseline_output_warning(
    Some("0123456789abcdef"),
    GitDirtyStatus::Clean,
  )
  inspect(actual, content="None")
}

///|
test "read_git_head_hash: HEAD ref" {
  let fs = @vfs.MemVFS::new()
  fs.write_string("/repo/.git/HEAD", "ref: refs/heads/main\n")
  fs.write_string("/repo/.git/refs/heads/main", "deadbeef\n")
  let actual = read_git_head_hash(fs, "/repo")
  inspect(actual, content="Some(\"deadbeef\")")
}

///|
test "read_git_head_hash: gitdir indirection" {
  let fs = @vfs.MemVFS::new()
  fs.write_string("/repo/.git", "gitdir: /repo/.actual-git\n")
  fs.write_string("/repo/.actual-git/HEAD", "ref: refs/heads/main\n")
  fs.write_string("/repo/.actual-git/refs/heads/main", "cafebabe\n")
  let actual = read_git_head_hash(fs, "/repo")
  inspect(actual, content="Some(\"cafebabe\")")
}
