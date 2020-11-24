#!/bin/sh

xcodebuild -workspace Hammerspoon.xcworkspace -scheme Release test-without-building 2>&1 | tee test.log

RESULT=$(cat test.log | grep -A1 "Test Suite 'All tests'" | tail -1)

echo "::set-output name=test_result::${RESULT}"

if [[ "${RESULT}" == *"0 failures"* ]]; then
    echo "::set-output name=test_result_short::Passed"
    exit 0
else
    echo "::set-output name=test_result_short::Failed"
    exit 1
fi
