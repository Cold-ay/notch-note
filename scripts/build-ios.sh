#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
if command -v xcodegen >/dev/null 2>&1; then
  generator="$(command -v xcodegen)"
elif [[ -x .build/tools/xcodegen/bin/xcodegen ]]; then
  generator="$PWD/.build/tools/xcodegen/bin/xcodegen"
else
  print -u2 'Install XcodeGen first: brew install xcodegen'
  exit 1
fi
"$generator" generate
common=(-project NotchAgenda.xcodeproj -scheme NotchAgenda-iOS -derivedDataPath "$PWD/.build/ios")
case "${1:---simulator}" in
  --simulator)
    xcodebuild "${common[@]}" -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
    mkdir -p .build/distribution
    ditto -c -k --keepParent .build/ios/Build/Products/Debug-iphonesimulator/NotchAgenda.app .build/distribution/NotchAgenda-simulator.zip
    print 'Simulator only: .build/distribution/NotchAgenda-simulator.zip'
    ;;
  --test)
    if [[ -z "${IOS_SIMULATOR_ID:-}" ]]; then
      IOS_SIMULATOR_ID="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; devices=json.load(sys.stdin)["devices"]; print(next(d["udid"] for group in devices.values() for d in group if d["isAvailable"] and d["name"].startswith("iPhone")))')"
    fi
    result_dir="$PWD/.build/test-results/ios-$(date +%Y%m%d-%H%M%S).xcresult"
    mkdir -p .build/test-results
    xcodebuild "${common[@]}" -destination "platform=iOS Simulator,id=$IOS_SIMULATOR_ID" -parallel-testing-enabled NO -resultBundlePath "$result_dir" CODE_SIGNING_ALLOWED=NO test
    ;;
  --unsigned-archive)
    xcodebuild "${common[@]}" -destination 'generic/platform=iOS' -archivePath "$PWD/.build/distribution/NotchAgenda-unsigned.xcarchive" CODE_SIGNING_ALLOWED=NO archive
    print 'Unsigned build verification only. This archive cannot be installed on an iPhone.'
    ;;
  --archive)
    : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID to your Apple Developer Team ID.}"
    xcodebuild "${common[@]}" -destination 'generic/platform=iOS' -archivePath "$PWD/.build/distribution/NotchAgenda.xcarchive" "DEVELOPMENT_TEAM=$APPLE_TEAM_ID" archive
    ;;
  --export)
    : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID to your Apple Developer Team ID.}"
    python3 - "$APPLE_TEAM_ID" <<'PY'
import plistlib,sys
from pathlib import Path
folder=Path('.build/distribution')
folder.mkdir(parents=True,exist_ok=True)
with (folder/'ExportOptions.plist').open('wb') as f:
    plistlib.dump({'method':'app-store-connect','destination':'export','signingStyle':'automatic','teamID':sys.argv[1],'uploadSymbols':True},f)
PY
    xcodebuild -exportArchive -archivePath "$PWD/.build/distribution/NotchAgenda.xcarchive" -exportPath "$PWD/.build/distribution/AppStore" -exportOptionsPlist "$PWD/.build/distribution/ExportOptions.plist"
    ;;
  *) print -u2 'Usage: scripts/build-ios.sh --simulator|--test|--unsigned-archive|--archive|--export'; exit 2 ;;
esac
