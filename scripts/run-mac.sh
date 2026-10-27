#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_dir/.build/swift-cache"
swift build --package-path "$project_dir" --disable-sandbox --cache-path "$project_dir/.build/package-cache"
app_dir="$project_dir/.build/NotchAgenda.app"
qa_mode=false
if [[ "${1:-}" == "--qa" || "${1:-}" == "--qa-build-only" ]]; then
  qa_mode=true
  app_dir="$project_dir/.build/NotchAgenda-QA.app"
fi
mkdir -p "$app_dir/Contents/MacOS"
cp "$project_dir/.build/debug/NotchAgenda" "$app_dir/Contents/MacOS/NotchAgenda.next"
mv -f "$app_dir/Contents/MacOS/NotchAgenda.next" "$app_dir/Contents/MacOS/NotchAgenda"
python3 - "$app_dir/Contents/Info.plist" "$qa_mode" "$project_dir/.build/qa/tasks.json" <<'PY'
import plistlib
import sys
qa = sys.argv[2] == 'true'
info = {
    'CFBundleExecutable': 'NotchAgenda',
    'CFBundleIdentifier': 'com.colday.notchagenda.qa' if qa else 'com.colday.notchagenda.mac',
    'CFBundleName': 'NotchAgenda QA' if qa else 'NotchAgenda',
    'CFBundlePackageType': 'APPL',
    'CFBundleVersion': '6',
    'CFBundleShortVersionString': '0.6.0',
    'LSMinimumSystemVersion': '14.0',
    'NSHighResolutionCapable': True,
}
if qa:
    info['LSEnvironment'] = {'NOTCHAGENDA_DATA_FILE': sys.argv[3]}
with open(sys.argv[1], 'wb') as handle:
    plistlib.dump(info, handle)
PY
if [[ "${1:-}" != "--build-only" && "${1:-}" != "--qa-build-only" ]]; then
  open "$app_dir"
fi
