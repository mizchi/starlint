set shell := ["bash", "-cu"]

home := env_var("HOME")
bin := home + "/.local/bin/starlint"

build:
  moon build --target native cli

install: build
  mkdir -p {{home}}/.local/bin
  install -m 755 _build/native/release/build/cli/cli.exe {{bin}}

metrics-test:
  bash scripts/moon_metrics_test.sh

metrics-collect db=".metrics/moon_metrics.sqlite":
  bash scripts/moon_metrics.sh collect --db {{db}}

metrics-init-db db=".metrics/moon_metrics.sqlite":
  bash scripts/moon_metrics.sh init-db --db {{db}}
