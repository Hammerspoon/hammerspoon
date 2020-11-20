#!/bin/bash

make docs

xcodebuild -workspace Hammerspoon.xcworkspace -scheme Release build-for-testing GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES GCC_GENERATE_TEST_COVERAGE_FILES=YES | xcpretty

make build/html
