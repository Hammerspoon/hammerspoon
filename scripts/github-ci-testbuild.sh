#!/bin/bash
# Build for testing

set -eu
set -o pipefail

export IS_CI=1

./scripts/build.sh build -s Release -e -x "Hammerspoon/Build Configs/Hammerspoon-Test.xcconfig"
