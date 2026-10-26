#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_dir/.build/swift-cache"
swift build --package-path "$project_dir" --disable-sandbox --cache-path "$project_dir/.build/package-cache"
app_dir="$project_dir/.build/FlowTasks.app"
qa_mode=false
if [[ "${1:-}" == "--qa" || "${1:-}" == "--qa-build-only" ]]; then
  qa_mode=true
  app_dir="$project_dir/.build/FlowTasks-QA.app"
fi
mkdir -p "$app_dir/Contents/MacOS"
cp "$project_dir/.build/debug/FlowTasks" "$app_dir/Contents/MacOS/FlowTasks.next"
mv -f "$app_dir/Contents/MacOS/FlowTasks.next" "$app_dir/Contents/MacOS/FlowTasks"
python3 - "$app_dir/Contents/Info.plist" "$qa_mode" "$project_dir/.build/qa/tasks.json" <<'PY'
import plistlib
import sys
qa = sys.argv[2] == 'true'
info = {
    'CFBundleExecutable': 'FlowTasks',
    'CFBundleIdentifier': 'com.example.flowtasks.qa' if qa else 'com.example.flowtasks.mac',
    'CFBundleName': 'FlowTasks QA' if qa else 'FlowTasks',
    'CFBundlePackageType': 'APPL',
    'CFBundleVersion': '3',
    'CFBundleShortVersionString': '0.3.0',
    'LSMinimumSystemVersion': '14.0',
    'NSHighResolutionCapable': True,
}
if qa:
    info['LSEnvironment'] = {'FLOWTASKS_DATA_FILE': sys.argv[3]}
with open(sys.argv[1], 'wb') as handle:
    plistlib.dump(info, handle)
PY
if [[ "${1:-}" != "--build-only" && "${1:-}" != "--qa-build-only" ]]; then
  open "$app_dir"
fi
