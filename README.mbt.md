# moonlint

simple linter for MoonBit language.

## test

```
moon test --target wasm-gc
```

## basic usage

```
moonlint.exe # auto scan current project
moonlint.exe foo.mbt # check this file
```
## configuration

moonlint supports a JSON config file at `moonlint.json` or `.moonlint.json`.

### preset (recommended)

```
{
  "preset": "recommended"
}
```

The `recommended` preset enables: `fp`, `size`, `async`, `error` by default (perf is off).

### module/test categories

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
