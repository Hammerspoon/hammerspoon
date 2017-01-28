#!/bin/bash

killall Hammerspoon

make clean
make
make docs

rm -fr "$(xcodebuild -workspace Hammerspoon.xcworkspace -scheme Hammerspoon -configuration DEBUG -showBuildSettings | sort | uniq | grep " BUILT_PRODUCTS_DIR =" | awk '{ print $3 }')/Hammerspoon.app"

# signing with self-signed cert so I no longer have to reset accessibility all the time
codesign --verbose --sign "Internal Code Signing" "build/Hammerspoon.app/Contents/Frameworks/LuaSkin.framework/Versions/A"
codesign --verbose --sign "Internal Code Signing" "build/Hammerspoon.app"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
open -a $DIR/build/Hammerspoon.app
