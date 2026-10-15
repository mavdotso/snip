#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d /tmp/snip-recording-tests.XXXXXX)
trap 'rm -rf "$TEST_DIR"' EXIT
python3 - "$TEST_DIR" <<'PY'
from pathlib import Path
import sys
source = Path('main.swift').read_text().split('let snip = Snip()')[0]
start = source.index('func screencapture(')
end = source.index('\nfunc copyToClipboard', start)
source = source[:start] + '''var recordings: [[String]] = []
var completion: ((Bool) -> Void)?
func screencapture(_ args: [String], then: @escaping (Bool) -> Void = { _ in }) {
    recordings.append(args)
    completion = then
}
''' + source[end:]
source += '''
let snip = Snip()
snip.record()
assert(recordings.count == 1)
for flag in ["-i", "-v", "-g", "-A", "-U", "-d"] {
    assert(recordings[0].contains(flag), "Missing recording flag: \\(flag)")
}
assert(recordings[0].last!.hasSuffix(".mov"))
assert(URL(fileURLWithPath: recordings[0].last!).deletingLastPathComponent() == saveDir)
snip.record()
assert(recordings.count == 1, "Must not launch overlapping recordings")
completion?(false)
snip.record()
assert(recordings.count == 2, "Must allow retry after cancellation or failure")
completion?(true)
snip.record()
assert(recordings.count == 3, "Must allow another recording after success")
print("Recording command and lifecycle checks passed")
'''
Path(sys.argv[1], 'main.swift').write_text(source)
PY
swiftc -module-cache-path /tmp/snip-module-cache "$TEST_DIR/main.swift" -o "$TEST_DIR/test"
"$TEST_DIR/test"
