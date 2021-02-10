#!/bin/bash

mkdir -p artifacts

xcodebuild -workspace Hammerspoon.xcworkspace -scheme Release test-without-building 2>&1 | tee artifacts/test.log | xcpretty -r junit -f `xcpretty-actions-formatter`

RESULT=$(grep -A1 "Test Suite 'All tests'" artifacts/test.log | tail -1 | sed -e 's/^[ ]+//')

echo "::set-output name=test_result::${RESULT}"

if [[ "${RESULT}" == *"0 failures"* ]]; then
    echo "::set-output name=test_result_short::Passed"
    exit 0
else
    echo "::set-output name=test_result_short::Failed"
    exit 1
fi
