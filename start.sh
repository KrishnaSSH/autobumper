#!/bin/sh
set -e
REPO="KrishnaSSH/autobumper"
DIR="bin"
OUT="$DIR/autobumper"
VERSION_FILE="$DIR/version.txt"
mkdir -p "$DIR"
OS=$(uname | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  armv7l) ARCH="arm" ;;
  i386|i686) ARCH="386" ;;
  *) echo "unsupported arch: $ARCH"; exit 1 ;;
esac

IS_TERMUX=0
if [ -n "$PREFIX" ] && [ -d "/data/data/com.termux" ]; then
  IS_TERMUX=1
fi

case "$OS" in
  darwin)
    SHA_CMD="shasum -a 256"
    ;;
  linux)
    SHA_CMD="sha256sum"
    ;;
  *)
    echo "unsupported os: $OS"
    exit 1
    ;;
esac

run_binary() {
  chmod +x "$OUT"
  if [ "$IS_TERMUX" = "1" ]; then
    if ! command -v proot > /dev/null 2>&1; then
      echo "installing proot for Termux..."
      pkg install -y proot
    fi
    echo "running (Termux mode)"
    exec proot \
      -b "$PREFIX/etc/resolv.conf:/etc/resolv.conf" \
      -b "$PREFIX/etc/tls/cert.pem:/etc/ssl/cert.pem" \
      "$OUT"
  fi
  echo "running"
  exec "$OUT"
}

download_and_install() {
  local version="$1"
  local archive="autobumper-${OS}-${ARCH}-${version}.tar.gz"
  local base_url="https://github.com/$REPO/releases/download/$version"
  local tmp_archive="$DIR/$archive"
  local sum_file="$DIR/checksums.txt"

  echo "downloading checksums..."
  curl -fsSL "$base_url/checksums.txt" -o "$sum_file"

  echo "downloading: $archive"
  curl -L --fail -o "$tmp_archive" "$base_url/$archive"

  EXPECTED=$(awk -v f="$archive" '$2==f {print $1}' "$sum_file")
  ACTUAL=$($SHA_CMD "$tmp_archive" | awk '{print $1}')
  if [ "$EXPECTED" != "$ACTUAL" ]; then
    echo "checksum failed"
    rm -f "$tmp_archive"
    exit 1
  fi

  tar -xzf "$tmp_archive" -C "$DIR"
  EXTRACTED=$(tar -tzf "$tmp_archive" 2>/dev/null || tar -tzf "$tmp_archive")
  EXTRACTED=$(tar -tzf "$tmp_archive" | head -n 1)
  mv "$DIR/$EXTRACTED" "$OUT"
  rm -f "$tmp_archive"
  chmod +x "$OUT"
  echo "$version" > "$VERSION_FILE"
  echo "installed $version"
}

verify_checksum() {
  local version="$1"
  local archive="autobumper-${OS}-${ARCH}-${version}.tar.gz"
  local sum_file="$DIR/checksums.txt"

  if [ ! -f "$sum_file" ]; then
    return 1
  fi

  EXPECTED=$(awk -v f="$archive" '$2==f {print $1}' "$sum_file")
  if [ -z "$EXPECTED" ]; then
    return 1
  fi

  ACTUAL=$($SHA_CMD "$OUT" | awk '{print $1}')

  BIN_NAME="autobumper"
  BIN_EXPECTED=$(awk -v f="$BIN_NAME" '$2==f {print $1}' "$sum_file")
  if [ -n "$BIN_EXPECTED" ]; then
    if [ "$BIN_EXPECTED" != "$ACTUAL" ]; then
      return 1
    fi
  fi
  return 0
}

echo "fetching latest release..."
API_JSON=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")
LATEST_VERSION=$(printf "%s" "$API_JSON" | grep '"tag_name"' | head -n 1 | cut -d '"' -f4)
CURRENT_VERSION=""
[ -f "$VERSION_FILE" ] && CURRENT_VERSION=$(cat "$VERSION_FILE")
echo "current: $CURRENT_VERSION"
echo "latest: $LATEST_VERSION"

if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ] && [ -f "$OUT" ]; then
  echo "versions match, verifying checksum..."
  if verify_checksum "$LATEST_VERSION"; then
    echo "checksum ok, already up to date"
    run_binary
  else
    echo "checksum missing or mismatch — redownloading..."
    download_and_install "$LATEST_VERSION"
    run_binary
  fi
else
  echo "update available, downloading..."
  download_and_install "$LATEST_VERSION"
  run_binary
fi
