#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

"${DIR}/scripts/build.sh" clean
"${DIR}/scripts/build.sh" build
"${DIR}/scripts/build.sh" docs

killall Hammerspoon
open -a "$DIR/build/Hammerspoon.app"
