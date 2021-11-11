#!/bin/bash
# Build for testing

set -eu
set -o pipefail

export IS_CI=1

mkdir -p artifacts

./scripts/build.sh build -s Release -d -e -x "Hammerspoon/Build Configs/Hammerspoon-Test.xcconfig"

# Note that even though we're building with the Release scheme, the above build actually uses the Debug configuration, so the output log is Debug-build.log
mv build/Debug-build.log artifacts/build.log
