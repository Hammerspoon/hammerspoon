#!/bin/bash

#
# Compile FCPX Hacks:
#
make clean
make release
make docs

rm -fr `xcodebuild -workspace Hammerspoon.xcworkspace -scheme Hammerspoon -configuration DEBUG -showBuildSettings | sort | uniq | grep " BUILT_PRODUCTS_DIR =" | awk '{ print $3 }'`/CommandPost.app

#
# Copy CommandPost Files:
#
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cp -R $DIR/../fcpxhacks/* $DIR/../build/CommandPost.app/Contents/Resources/extensions/hs/

#
# Remove all extended attributes from App Bundle (https://developer.apple.com/library/content/qa/qa1940/_index.html):
#
xattr -cr $DIR/../build/FCPXHacks.app $DIR/../build/CommandPost.app

#
# Signing with self-signed cert so I no longer have to reset accessibility all the time:
#
codesign --verbose --sign "Internal Code Signing" "build/CommandPost.app/Contents/Frameworks/Sparkle.framework/Versions/A"
codesign --verbose --sign "Internal Code Signing" "build/CommandPost.app/Contents/Frameworks/LuaSkin.framework/Versions/A"
codesign --verbose --sign "Internal Code Signing" "build/CommandPost.app"

#
# Trash Preferences:
#
rm ~/Library/Preferences/org.latenitefilms.CommandPost.plist