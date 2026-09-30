#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d /tmp/snip-tests.XXXXXX)
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/Test.app/Contents/MacOS" "$TEST_DIR/Test.app/Contents/Resources"
cp -R assets/hugeicons "$TEST_DIR/Test.app/Contents/Resources/"
python3 - "$TEST_DIR" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
source = Path('main.swift').read_text().split('let snip = Snip()')[0]
source = source.replace('FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")', 'URL(fileURLWithPath: "' + str(root / 'Desktop') + '")')
(root / 'main.swift').write_text(source + Path('tests/preview.swift').read_text())
PY
swiftc -module-cache-path /tmp/snip-module-cache "$TEST_DIR/main.swift" -o "$TEST_DIR/Test.app/Contents/MacOS/Test"
"$TEST_DIR/Test.app/Contents/MacOS/Test"
