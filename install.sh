#!/usr/bin/env sh
set -e

REPO="mizchi/starlint"
INSTALL_DIR="${STARLINT_INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${STARLINT_VERSION:-${1:-}}"

if [ -z "$VERSION" ]; then
  VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | \
    awk -F '"' '/"tag_name"/ {print $4; exit}')
fi

if [ -z "$VERSION" ]; then
  echo "failed to resolve latest version" >&2
  exit 1
fi

OS=$(uname -s)
ARCH=$(uname -m)

case "$OS" in
  Darwin) OS="macos" ;;
  Linux) OS="linux" ;;
  *)
    echo "unsupported OS: $OS" >&2
    exit 1
    ;;
 esac

case "$ARCH" in
  arm64|aarch64) ARCH="arm64" ;;
  x86_64|amd64) ARCH="x64" ;;
  *)
    echo "unsupported arch: $ARCH" >&2
    exit 1
    ;;
 esac

ASSET="starlint-${OS}-${ARCH}.tar.gz"
URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET}"

TMPDIR=$(mktemp -d)
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

curl -fsSL "$URL" -o "$TMPDIR/$ASSET"

tar -C "$TMPDIR" -xzf "$TMPDIR/$ASSET"

mkdir -p "$INSTALL_DIR"

if command -v install >/dev/null 2>&1; then
  install -m 755 "$TMPDIR/starlint" "$INSTALL_DIR/starlint"
else
  cp "$TMPDIR/starlint" "$INSTALL_DIR/starlint"
  chmod +x "$INSTALL_DIR/starlint"
fi

echo "starlint installed to $INSTALL_DIR/starlint"
