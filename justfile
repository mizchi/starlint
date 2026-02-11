set shell := ["bash", "-cu"]

build:
  moon build --target native cmd/starlint

install:
  moon install ./cmd/starlint

metrics-test:
  bash scripts/moon_metrics_test.sh

metrics-collect db=".metrics/moon_metrics.sqlite":
  bash scripts/moon_metrics.sh collect --db {{db}}

metrics-init-db db=".metrics/moon_metrics.sqlite":
  bash scripts/moon_metrics.sh init-db --db {{db}}
