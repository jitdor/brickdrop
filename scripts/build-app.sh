#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(dirname "$SCRIPT_DIR")
APP_DIR="$PROJECT_DIR/dist/BrickDrop.app"
CONTENTS_DIR="$APP_DIR/Contents"

cd "$PROJECT_DIR"
swift build --disable-sandbox -c release
BIN_DIR=$(swift build --disable-sandbox -c release --show-bin-path)

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS"
cp "$BIN_DIR/BrickDrop" "$CONTENTS_DIR/MacOS/BrickDrop"
cp "$PROJECT_DIR/Support/Info.plist" "$CONTENTS_DIR/Info.plist"
codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"
