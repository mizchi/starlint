set shell := ["bash", "-cu"]

home := env_var("HOME")
bin := home + "/.local/bin/moonlint"

build:
  moon build --target native cli

install: build
  mkdir -p {{home}}/.local/bin
  install -m 755 _build/native/release/build/cli/cli.exe {{bin}}
