#!/bin/bash

set -e
set -o pipefail

mkdir -p artifacts

xcodebuild -workspace Hammerspoon.xcworkspace -scheme Release build-for-testing GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES GCC_GENERATE_TEST_COVERAGE_FILES=YES | tee artifacts/build.log | xcpretty -f `xcpretty-actions-formatter`
