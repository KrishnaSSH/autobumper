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
    TARGET="autobumper-darwin-$ARCH"
    SHA_CMD="shasum -a 256"
    ;;
  linux)
    TARGET="autobumper-linux-$ARCH"
    SHA_CMD="sha256sum"
    ;;
  *)
    echo "unsupported os: $OS"
    exit 1
    ;;
esac
echo "fetching latest release..."
API_JSON=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")
LATEST_VERSION=$(printf "%s" "$API_JSON" | grep '"tag_name"' | head -n 1 | cut -d '"' -f4)
CURRENT_VERSION=""
[ -f "$VERSION_FILE" ] && CURRENT_VERSION=$(cat "$VERSION_FILE")
echo "current: $CURRENT_VERSION"
echo "latest: $LATEST_VERSION"
if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ] && [ -f "$OUT" ]; then
  echo "already up to date"
  chmod +x "$OUT"
  if [ "$IS_TERMUX" = "1" ]; then
    exec proot \
      -b "$PREFIX/etc/resolv.conf:/etc/resolv.conf" \
      -b "$PREFIX/etc/tls/cert.pem:/etc/ssl/cert.pem" \
      "$OUT"
  fi
  exec "$OUT"
fi
FILE="$TARGET-$LATEST_VERSION"
BASE_URL="https://github.com/$REPO/releases/download/$LATEST_VERSION"
BIN_URL="$BASE_URL/$FILE"
SUM_URL="$BASE_URL/checksums.txt"
TMP="$OUT.tmp"
SUM_FILE="$DIR/checksums.txt"
echo "downloading update: $FILE"
curl -L --fail -o "$TMP" "$BIN_URL"
curl -fsSL "$SUM_URL" -o "$SUM_FILE"
EXPECTED=$(awk -v f="$FILE" '$2==f {print $1}' "$SUM_FILE")
ACTUAL=$($SHA_CMD "$TMP" | awk '{print $1}')
if [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "checksum failed"
  rm -f "$TMP"
  exit 1
fi
chmod +x "$TMP"
mv "$TMP" "$OUT"
echo "$LATEST_VERSION" > "$VERSION_FILE"

if [ "$IS_TERMUX" = "1" ]; then
  # install proot if missing
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
