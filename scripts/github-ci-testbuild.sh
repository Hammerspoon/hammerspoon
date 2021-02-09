#!/bin/bash

set -e
set -o pipefail

make docs

xcodebuild -workspace Hammerspoon.xcworkspace -scheme Release build-for-testing GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES GCC_GENERATE_TEST_COVERAGE_FILES=YES | xcpretty -f `xcpretty-actions-formatter`

make build/html
