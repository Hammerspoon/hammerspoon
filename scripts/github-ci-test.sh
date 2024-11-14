#!/bin/bash
# Run tests

set -eux
set -o pipefail

export IS_CI=1

mkdir -p artifacts
mkdir -p build/reports

./scripts/build.sh test -e -d -s Release

cp build/test.log artifacts
cp -r build/TestResults.xcresult artifacts
xcresultparser --output-format cobertura build/TestResults.xcresult >artifacts/coverage.xml

RESULT=$(grep -A1 "Test Suite 'All tests'" artifacts/test.log | tail -1 | sed -e 's/^[ ]+//')

echo "test_result=${RESULT}" >> $GITHUB_OUTPUT

if [[ "${RESULT}" == *"0 failures"* ]]; then
    echo "test_result_short=Passed" >> $GITHUB_OUTPUT
    exit 0
else
    echo "test_result_short=Failed" >> $GITHUB_OUTPUT
    exit 1
fi
