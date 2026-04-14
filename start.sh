#!/bin/sh

set -e

REPO="KrishnaSSH/autobumper"
DIR="bin"
OUT="$DIR/autobumper"

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

case "$OS" in
  darwin)
    TARGET="autobumper-darwin-$ARCH"
    PLATFORM="macos (darwin)"
    SHA_CMD="shasum -a 256"
    ;;
  linux)
    TARGET="autobumper-linux-$ARCH"
    PLATFORM="linux"
    SHA_CMD="sha256sum"
    ;;
  *)
    echo "unsupported os: $OS"
    exit 1
    ;;
esac

echo "platform: $PLATFORM"
echo "fetching latest release..."

API_JSON=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")

VERSION=$(printf "%s" "$API_JSON" | grep '"tag_name"' | head -n 1 | cut -d '"' -f 4)

BASE_URL="https://github.com/$REPO/releases/download/$VERSION"

FILE="$TARGET-$VERSION"
BIN_URL="$BASE_URL/$FILE"
SUM_URL="$BASE_URL/checksums.txt"

TMP="$OUT.tmp"
SUM_FILE="$DIR/checksums.txt"

echo "latest version: $VERSION"
echo "asset: $FILE"

if [ -f "$OUT" ]; then
  echo "verifying checksum of existing binary..."

  curl -fsSL "$SUM_URL" -o "$SUM_FILE"

  EXPECTED=$(awk -v f="$FILE" '$2==f {print $1}' "$SUM_FILE")
  ACTUAL=$($SHA_CMD "$OUT" | awk '{print $1}')

  if [ "$EXPECTED" = "$ACTUAL" ]; then
    echo "checksum valid, running"
    chmod +x "$OUT"
    exec "$OUT"
  else
    echo "checksum mismatch, redownloading"
    rm -f "$OUT"
  fi
fi

echo "downloading binary..."
curl -L --fail --retry 3 --retry-delay 2 \
  --connect-timeout 10 \
  -o "$TMP" "$BIN_URL"

echo "downloading checksums..."
curl -fsSL "$SUM_URL" -o "$SUM_FILE"

EXPECTED=$(awk -v f="$FILE" '$2==f {print $1}' "$SUM_FILE")
ACTUAL=$($SHA_CMD "$TMP" | awk '{print $1}')

if [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "checksum verification failed"
  rm -f "$TMP"
  exit 1
fi

echo "checksum verified"

chmod +x "$TMP"
mv "$TMP" "$OUT"

echo "running"
exec "$OUT"