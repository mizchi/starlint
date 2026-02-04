# starlint

simple linter for MoonBit language.

## test

```
moon test --target wasm-gc
```

## basic usage

```
starlint # auto scan current project
starlint foo.mbt # check this file
starlint --by-rule foo.mbt # group diagnostics by rule
starlint doc # show rule list and defaults
starlint init # generate starlint.json (with rule_groups guidance)
starlint --ai # output AI review metadata (module/file/function/test names + doc tests)
```

starlint walks up from the current directory to find `moon.mod.json`, and uses that
module root as the base for config and file discovery.

You can also start from a specific directory:

```
starlint --config path/to/starlint.json src/foo.mbt
```

## embed as CLI main

Use starlint as a library-driven CLI by calling `@cli.run(...)` from your own
`main` (e.g. `src/internal/cli.mbt`).

```
// moon.pkg
import {
  "mizchi/starlint/cli",
  "moonbitlang/x/sys",
}
```

```mbt
///|
fn main {
  let argv = @sys.get_cli_args()[1:].to_array()
  @cli.run(argv) // uses PWD (or INIT_CWD) to locate moon.mod.json
  // or: @cli.run(argv, start_dir="path/to/project")
}
```

## install

```
curl -fsSL https://raw.githubusercontent.com/mizchi/starlint/main/install.sh | sh
```

Optional environment variables:

- `STARLINT_VERSION` to pin a tag (e.g. `v0.1.0`)
- `STARLINT_INSTALL_DIR` to change the install directory (default: `$HOME/.local/bin`)

For local development builds:

```
just install
```

## configuration

starlint supports a JSON config file at `starlint.json` or `.starlint.json`.

### preset (recommended)

```
{
  "preset": "recommended"
}
```

The `recommended` preset enables: `fp`, `size`, `async`, `error` by default (perf is off).

### module/test categories (optional)

These are optional add-ons. `module` includes doc comment requirements for `pub fn` / `pub enum`,
which can be noisy, so it is **off by default**. Enable when you want stricter module conventions.

```
{
  "preset": "recommended",
  "categories": {
    "module": { "enabled": true },
    "test": { "enabled": true }
  }
}
```

- `module` rules enforce doc comments on `pub fn` / `pub enum`, and restrict `using` to `file.mbt`.
- `test` rules detect trivial asserts and prefer input/expected/actual style.

### ignore / overrides

```
{
  "ignore": ["target/*", "_build/*", "*.gen.mbt"],
  "overrides": [
    {
      "files": ["tests/*", "*_test.mbt"],
      "rules": { "prefer_arrow_fn": "off" },
      "categories": { "perf": { "enabled": false } }
    }
  ]
}
```

- `ignore` skips matching files.
- `overrides` applies per-file rule/category settings. Patterns use `*`; if a pattern contains `/`, it matches the full path, otherwise the basename.
