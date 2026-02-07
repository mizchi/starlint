///|
fn[FS : @vfs.VFS] run_baseline(
  fs : FS,
  module_root : String,
  compare_path : String,
) -> Unit {
  let module_info = load_module_info(fs, module_root) catch {
    err => {
      println("failed to load module info: \{err}")
      panic()
    }
  }
  let module_name = get_module_name(module_info)
  let base_rel = get_src_location(module_info)
  let base_fs = if base_rel == "." || base_rel == "" {
    module_root
  } else {
    join_path(module_root, base_rel)
  }
  let file_entries = build_file_entries_from_module(
    fs, module_root, base_fs, base_rel,
  ) catch {
    err => {
      println("failed when finding source files: \{err}")
      panic()
    }
  }
  let rules = @lint.rules()
  let config = match default_config_path(fs, module_root) {
    Some(path) =>
      load_config(fs, path) catch {
        err => {
          println("failed to load config: \{err}")
          panic()
        }
      }
    None => @starlint.LintConfig::recommended()
  }
  // Collect metrics per file and per package
  let pkg_data : Map[String, PackageAccum] = Map::new()
  let file_baselines : Map[String, @starlint.FileBaseline] = Map::new()
  let all_diagnostics = []
  let mut total_loc = 0
  let mut total_functions = 0
  let mut total_complexity_sum = 0
  let mut global_max_complexity = 0
  for entry in file_entries {
    let (fs_path, display_path) = entry
    let file_config = config.for_file(display_path)
    if file_config.is_ignored(display_path) {
      continue
    }
    let parse_result : Result[(@syntax.Impls, String), Error] = try? read_mbt_file_to_impls(
      fs, fs_path, display_path,
    )
    match parse_result {
      Ok((impls, source)) => {
        let package_name = package_name_for_file(module_name, display_path)
        let loc = @starlint.count_loc(source)
        total_loc += loc
        // Complexity
        let functions = @starlint.compute_file_complexity(impls, source)
        let mut file_max = 0
        let mut file_sum = 0
        for fc in functions {
          file_sum += fc.complexity
          if fc.complexity > file_max {
            file_max = fc.complexity
          }
        }
        total_functions += functions.length()
        total_complexity_sum += file_sum
        if file_max > global_max_complexity {
          global_max_complexity = file_max
        }
        let complexity_avg = if functions.length() > 0 {
          file_sum.to_double() / functions.length().to_double()
        } else {
          0.0
        }
        file_baselines.set(display_path, @starlint.FileBaseline::{
          package_name,
          loc,
          functions,
          complexity_avg,
          complexity_max: file_max,
        })
        // Package accumulation
        let accum = match pkg_data.get(package_name) {
          Some(a) => a
          None => {
            let a = PackageAccum::{
              pub_fn_count: 0,
              pub_type_count: 0,
              pub_api_names: [],
              test_count: 0,
              loc: 0,
            }
            pkg_data.set(package_name, a)
            a
          }
        }
        accum.loc += loc
        collect_package_metrics(impls, accum)
        // Diagnostics
        let input = @starlint.LintInput::new(
          impls~,
          source~,
          filename=display_path,
        )
        let file_diags = @starlint.lint_with_config(input, rules, file_config)
        for diag in file_diags {
          all_diagnostics.push(diag)
        }
      }
      Err(err) => println("warning: failed to parse \{display_path}: \{err}")
    }
  }
  // Build package baselines
  let packages : Map[String, @starlint.PackageBaseline] = Map::new()
  for name, accum in pkg_data {
    accum.pub_api_names.sort_by((a, b) => a.compare(b))
    packages.set(name, @starlint.PackageBaseline::{
      pub_fn_count: accum.pub_fn_count,
      pub_type_count: accum.pub_type_count,
      pub_api_names: accum.pub_api_names,
      test_count: accum.test_count,
      loc: accum.loc,
    })
  }
  // Build diagnostics summary
  let by_rule : Map[String, Int] = Map::new()
  for diag in all_diagnostics {
    let current = match by_rule.get(diag.rule_id) {
      Some(c) => c
      None => 0
    }
    by_rule.set(diag.rule_id, current + 1)
  }
  let diagnostics_summary = @starlint.DiagnosticsSummary::{
    total: all_diagnostics.length(),
    by_rule,
  }
  // Compute total pub APIs and tests
  let mut total_pub_apis = 0
  let mut total_tests = 0
  for _, pkg in packages {
    total_pub_apis += pkg.pub_fn_count + pkg.pub_type_count
    total_tests += pkg.test_count
  }
  let avg_complexity = if total_functions > 0 {
    total_complexity_sum.to_double() / total_functions.to_double()
  } else {
    0.0
  }
  let summary = @starlint.BaselineSummary::{
    total_files: file_baselines.length(),
    total_loc,
    total_packages: packages.length(),
    total_pub_apis,
    total_tests,
    total_diagnostics: all_diagnostics.length(),
    avg_complexity,
    max_complexity: global_max_complexity,
  }
  let baseline = @starlint.Baseline::{
    version: "1",
    packages,
    files: file_baselines,
    diagnostics: diagnostics_summary,
    summary,
  }
  if compare_path != "" {
    // Compare mode
    let old_text = fs.read_string(compare_path) catch {
      err => {
        println("failed to read baseline file: \{err}")
        panic()
      }
    }
    let old_baseline = @starlint.Baseline::from_json(old_text) catch {
      err => {
        println("failed to parse baseline file: \{err}")
        panic()
      }
    }
    let comparison = @starlint.compare_baselines(old_baseline, baseline)
    println(@starlint.format_comparison(comparison))
  } else {
    // Write baseline
    let git_hash = read_git_head_hash(fs, module_root)
    let git_status = detect_git_dirty_status(module_root)
    let output_rel_path = resolve_baseline_output_rel_path(git_hash, git_status)
    let output_path = join_path(module_root, output_rel_path)
    ensure_baseline_output_dir(module_root)
    let json_text = baseline.to_json()
    fs.write_string(output_path, json_text) catch {
      err => {
        println("failed to write baseline: \{err}")
        panic()
      }
    }
    match baseline_output_warning(git_hash, git_status) {
      Some(message) => println(message)
      None => ()
    }
    println("Baseline written to \{output_rel_path}")
    println("  files: \{summary.total_files}")
    println("  loc: \{summary.total_loc}")
    println("  packages: \{summary.total_packages}")
    println("  pub APIs: \{total_pub_apis}")
    println("  tests: \{total_tests}")
    println("  diagnostics: \{all_diagnostics.length()}")
    println("  avg complexity: \{@starlint.format_double(avg_complexity)}")
    println("  max complexity: \{global_max_complexity}")
  }
}

///|
enum GitDirtyStatus {
  Clean
  Dirty
  Unknown
}

///|
fn resolve_baseline_output_rel_path(
  git_hash : String?,
  git_status : GitDirtyStatus,
) -> String {
  let filename = match (git_hash, git_status) {
    (Some(hash), GitDirtyStatus::Clean) => "\{hash}.json"
    _ => "latest.json"
  }
  join_path(".starlint", filename)
}

///|
fn baseline_output_warning(
  git_hash : String?,
  git_status : GitDirtyStatus,
) -> String? {
  match git_status {
    GitDirtyStatus::Dirty =>
      Some(
        "warning: git worktree is dirty; baseline is saved to .starlint/latest.json",
      )
    GitDirtyStatus::Unknown =>
      Some(
        "warning: failed to detect git worktree state; baseline is saved to .starlint/latest.json",
      )
    GitDirtyStatus::Clean =>
      match git_hash {
        Some(_) => None
        None =>
          Some(
            "warning: failed to resolve git hash; baseline is saved to .starlint/latest.json",
          )
      }
  }
}

///|
fn ensure_baseline_output_dir(module_root : String) -> Unit {
  let out_dir = join_path(module_root, ".starlint")
  if @fs.path_exists(out_dir) {
    return
  }
  @fs.create_dir(out_dir) catch {
    _ => ()
  }
}

///|
fn detect_git_dirty_status(module_root : String) -> GitDirtyStatus {
  let repo_check = run_git_exit_code(module_root, [
    "rev-parse", "--is-inside-work-tree",
  ])
  if repo_check != 0 {
    return GitDirtyStatus::Unknown
  }
  match
    is_dirty_exit_code(
      run_git_exit_code(module_root, [
        "diff", "--quiet", "--ignore-submodules", "--",
      ]),
    ) {
    Some(true) => return GitDirtyStatus::Dirty
    Some(false) => ()
    None => return GitDirtyStatus::Unknown
  }
  match
    is_dirty_exit_code(
      run_git_exit_code(module_root, [
        "diff", "--cached", "--quiet", "--ignore-submodules", "--",
      ]),
    ) {
    Some(true) => return GitDirtyStatus::Dirty
    Some(false) => ()
    None => return GitDirtyStatus::Unknown
  }
  let untracked_cmd = shell_test_no_untracked(module_root)
  let untracked_code = run_shell_exit_code(untracked_cmd)
  if untracked_code == 1 {
    return GitDirtyStatus::Dirty
  }
  if untracked_code != 0 {
    return GitDirtyStatus::Unknown
  }
  GitDirtyStatus::Clean
}

///|
fn is_dirty_exit_code(exit_code : Int) -> Bool? {
  if exit_code == 0 {
    return Some(false)
  }
  if exit_code == 1 {
    return Some(true)
  }
  None
}

///|
fn shell_test_no_untracked(module_root : String) -> String {
  let sb = StringBuilder::new()
  sb
  ..write_string("test -z \"$(git -C ")
  ..write_string(shell_escape(module_root))
  ..write_string(" ls-files --others --exclude-standard 2>/dev/null)\"")
  sb.to_string()
}

///|
fn run_git_exit_code(module_root : String, args : Array[String]) -> Int {
  let sb = StringBuilder::new()
  sb..write_string("git -C ")..write_string(shell_escape(module_root))
  if args.length() > 0 {
    sb.write_string(" ")
    sb.write_string(shell_join(args))
  }
  sb.write_string(" >/dev/null 2>/dev/null")
  run_shell_exit_code(sb.to_string())
}

///|
fn run_shell_exit_code(cmd : String) -> Int {
  let raw = system(to_c_string(cmd))
  if raw < 0 {
    return raw
  }
  if raw >= 256 {
    return raw / 256
  }
  raw
}

///|
fn shell_join(args : Array[String]) -> String {
  let sb = StringBuilder::new()
  let mut first = true
  for arg in args {
    if first {
      first = false
    } else {
      sb.write_string(" ")
    }
    sb.write_string(shell_escape(arg))
  }
  sb.to_string()
}

///|
fn shell_escape(s : String) -> String {
  let sb = StringBuilder::new()
  sb.write_char('\'')
  for c in s {
    if c == '\'' {
      sb.write_char('\'')
      sb.write_char('\\')
      sb.write_char('\'')
      sb.write_char('\'')
    } else {
      sb.write_char(c)
    }
  }
  sb.write_char('\'')
  sb.to_string()
}

///|
fn to_c_string(s : String) -> Bytes {
  let bytes = @utf8.encode(s)
  let arr = bytes.to_array()
  arr.push(0)
  Bytes::from_array(arr)
}

///|
#borrow(cmd)
extern "C" fn system(cmd : Bytes) -> Int = "system"

///|
fn[FS : @vfs.VFS] resolve_git_dir(fs : FS, module_root : String) -> String? {
  let git_marker = join_path(module_root, ".git")
  if !fs.path_exists(git_marker) {
    return None
  }
  let is_dir = fs.is_dir(git_marker) catch { _ => false }
  if is_dir {
    return Some(git_marker)
  }
  let git_file = fs.read_string(git_marker) catch { _ => return None }
  parse_git_dir_from_marker(module_root, git_file)
}

///|
fn parse_git_dir_from_marker(
  module_root : String,
  marker_content : String,
) -> String? {
  let trimmed = marker_content.trim().to_string()
  if !trimmed.has_prefix("gitdir:") {
    return None
  }
  let rest = try trimmed[7:] catch {
    _ => ""
  } noraise {
    view => view.to_string().trim().to_string()
  }
  if rest == "" {
    return None
  }
  if is_abs_path(rest) {
    Some(rest)
  } else {
    Some(join_path(module_root, rest))
  }
}

///|
fn normalize_git_hash(raw : String) -> String? {
  let trimmed = raw.trim().to_string()
  if trimmed == "" {
    None
  } else {
    Some(trimmed)
  }
}

///|
fn[FS : @vfs.VFS] read_git_head_hash(fs : FS, module_root : String) -> String? {
  let git_dir = match resolve_git_dir(fs, module_root) {
    Some(path) => path
    None => return None
  }
  let head = fs.read_string(join_path(git_dir, "HEAD")) catch {
    _ => return None
  }
  let head_trimmed = head.trim().to_string()
  if !head_trimmed.has_prefix("ref:") {
    return normalize_git_hash(head_trimmed)
  }
  let ref_name = try head_trimmed[4:] catch {
    _ => ""
  } noraise {
    view => view.to_string().trim().to_string()
  }
  if ref_name == "" {
    return None
  }
  read_git_ref_hash(fs, git_dir, ref_name)
}

///|
fn[FS : @vfs.VFS] read_git_ref_hash(
  fs : FS,
  git_dir : String,
  ref_name : String,
) -> String? {
  let ref_path = join_path(git_dir, ref_name)
  let direct = fs.read_string(ref_path) catch { _ => "" }
  match normalize_git_hash(direct) {
    Some(hash) => Some(hash)
    None => read_git_ref_hash_from_packed_refs(fs, git_dir, ref_name)
  }
}

///|
fn[FS : @vfs.VFS] read_git_ref_hash_from_packed_refs(
  fs : FS,
  git_dir : String,
  ref_name : String,
) -> String? {
  let packed = fs.read_string(join_path(git_dir, "packed-refs")) catch {
    _ => return None
  }
  for part in packed.split("\n") {
    let line = part.to_string().trim().to_string()
    if line == "" || line.has_prefix("#") || line.has_prefix("^") {
      continue
    }
    match line.find(" ") {
      Some(idx) => {
        let hash = try line[:idx] catch {
          _ => continue
        } noraise {
          view => view.to_string()
        }
        let ref_part = try line[idx + 1:] catch {
          _ => continue
        } noraise {
          view => view.to_string().trim().to_string()
        }
        if ref_part == ref_name {
          return normalize_git_hash(hash)
        }
      }
      None => ()
    }
  }
  None
}

///|
fn[FS : @vfs.VFS] default_analyze_compare_path(
  fs : FS,
  module_root : String,
) -> String {
  let base_dir = join_path(module_root, ".starlint")
  let latest_path = join_path(base_dir, "latest.json")
  if fs.path_exists(latest_path) {
    return latest_path
  }
  match read_git_head_hash(fs, module_root) {
    Some(hash) => {
      let hash_path = join_path(base_dir, "\{hash}.json")
      if fs.path_exists(hash_path) {
        hash_path
      } else {
        latest_path
      }
    }
    None => latest_path
  }
}

///|
priv struct PackageAccum {
  mut pub_fn_count : Int
  mut pub_type_count : Int
  pub_api_names : Array[String]
  mut test_count : Int
  mut loc : Int
}

///|
fn collect_package_metrics(impls : @syntax.Impls, accum : PackageAccum) -> Unit {
  for impl_ in impls {
    match impl_ {
      @syntax.Impl::TopFuncDef(fun_decl~, ..) =>
        if is_public_vis(fun_decl.vis) {
          accum.pub_fn_count += 1
          accum.pub_api_names.push(format_fun_decl_name(fun_decl))
        }
      @syntax.Impl::TopImpl(self_ty~, method_name~, vis~, ..) =>
        if is_public_vis(vis) {
          accum.pub_fn_count += 1
          accum.pub_api_names.push(
            format_impl_method_name(self_ty, method_name),
          )
        }
      @syntax.Impl::TopView(view_func_name~, vis~, ..) =>
        if is_public_vis(vis) {
          accum.pub_fn_count += 1
          accum.pub_api_names.push(view_func_name.name)
        }
      @syntax.Impl::TopTypeDef(type_decl) =>
        if is_public_vis(type_decl.type_vis) {
          accum.pub_type_count += 1
          accum.pub_api_names.push(type_decl.tycon)
        }
      @syntax.Impl::TopTrait(trait_decl) =>
        if is_public_vis(trait_decl.vis) {
          accum.pub_type_count += 1
          accum.pub_api_names.push(trait_decl.name.name)
        }
      @syntax.Impl::TopTest(..) => accum.test_count += 1
      _ => ()
    }
  }
}
