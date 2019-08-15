#!/bin/bash
# Abort on Error
set -e -o pipefail

export PING_SLEEP=30s
export WORKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export BUILD_OUTPUT=$HOME/build.log
export TEST_OUTPUT=$HOME/test.log
export OP=$1

touch $BUILD_OUTPUT
touch $TEST_OUTPUT
touch $HOME/codecov.log

echo "Build/test logs will be uploaded to: https://s3-eu-west-1.amazonaws.com/hammerspoontravisartifacts/index.html?prefix=logs/${TRAVIS_BUILD_NUMBER}/"

if [ "${OP}" == "build" ]; then
    export OUTPUT_FILE="${BUILD_OUTPUT}"
    export XCODE_ARGS="build build-for-testing GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES GCC_GENERATE_TEST_COVERAGE_FILES=YES"
elif [ "${OP}" == "test" ]; then
    echo "Test build, looking for libclang_rt.asan_osx_dynamic.dylib..."
    ASAN_LIB_PATH=$(find /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/ -name libclang_rt.asan_osx_dynamic.dylib)
    if [ "${ASAN_LIB_PATH}" == "" ]; then
        echo "No asan lib found, failing"
        exit 1
    fi
    echo "ASAN_LIB_PATH: ${ASAN_LIB_PATH}"
    export DYLD_INSERT_LIBRARIES="${ASAN_LIB_PATH}"
    export OUTPUT_FILE="${TEST_OUTPUT}"
    export XCODE_ARGS="test-without-building"
else
    echo "Unknown command: ${OP}"
    exit 1
fi

dump_output() {
   echo Tailing the last 200 lines of output:
   tail -200 $OUTPUT_FILE
}

error_handler() {
  echo ERROR: An error was encountered with the build.
  kill $PING_LOOP_PID
  dump_output
  exit 1
}

# If an error occurs, run our error handler to output a tail of the build
trap 'error_handler' ERR

# Set up a repeating loop to send some output to Travis.
bash -c "while true; do echo \$(date) - ${OP}ing keepalive ...; sleep $PING_SLEEP; done" &
export PING_LOOP_PID=$!

# Build command
#mvn clean install >> $OUTPUT_FILE 2>&1
xcodebuild -workspace Hammerspoon.xcworkspace -scheme Release ${XCODE_ARGS} | tee $OUTPUT_FILE | xcpretty -f `xcpretty-travis-profiler-formatter`

echo "Log file: "
ls -l $OUTPUT_FILE

# nicely terminate the ping output loop
kill $PING_LOOP_PID
