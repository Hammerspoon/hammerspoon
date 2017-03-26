#!/bin/bash

#
# Compile CommandPost:
#
make clean
make release
make docs

rm -fr `xcodebuild -workspace Hammerspoon.xcworkspace -scheme Hammerspoon -configuration DEBUG -showBuildSettings | sort | uniq | grep " BUILT_PRODUCTS_DIR =" | awk '{ print $3 }'`/CommandPost.app

#
# Sign App with self-signed certificate:
#
codesign --verbose --sign "Internal Code Signing" "build/CommandPost.app/Contents/Frameworks/Sparkle.framework/Versions/A"
codesign --verbose --sign "Internal Code Signing" "build/CommandPost.app/Contents/Frameworks/LuaSkin.framework/Versions/A"
codesign --verbose --sign "Internal Code Signing" "build/CommandPost.app"