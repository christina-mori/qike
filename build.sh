#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build '栖刻.app/Contents/MacOS' '栖刻.app/Contents/Resources'
swiftc -module-cache-path build/module-cache Sources/TimerEngine.swift Tests/main.swift -o build/timer-tests
build/timer-tests
swift -module-cache-path build/module-cache Scripts/MakeIcon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o '栖刻.app/Contents/Resources/AppIcon.icns'
swiftc -O -module-cache-path build/module-cache -target arm64-apple-macosx14.0 Sources/*.swift -o '栖刻.app/Contents/MacOS/Qike' -framework SwiftUI -framework AppKit -framework UserNotifications -framework AVFoundation
cp Info.plist '栖刻.app/Contents/Info.plist'
cp ThirdParty/TomatoBar-LICENSE '栖刻.app/Contents/Resources/TomatoBar-LICENSE'
codesign --force --sign - '栖刻.app'
echo '已构建：栖刻.app'
