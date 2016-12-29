#!/bin/bash
# Abort on Error
set -e

export PING_SLEEP=30s
export WORKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export BUILD_OUTPUT=$HOME/build.log
export TEST_OUTPUT=$HOME/test.log
export OP=$1

touch $BUILD_OUTPUT
touch $TEST_OUTPUT

if [ "${OP}" == "build" ]; then
    export OUTPUT_FILE="${BUILD_OUTPUT}"
    export XCODE_ARGS="build build-for-testing GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES GCC_GENERATE_TEST_COVERAGE_FILES=YES"
elif [ "${OP}" == "test" ]; then
    export OUTPUT_FILE="${TEST_OUTPUT}"
    export XCODE_ARGS="test-without-building"
else
    echo "Unknown command: ${OP}"
    exit 1
fi

dump_output() {
   echo Tailing the last 500 lines of output:
   tail -500 $OUTPUT_FILE
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

bash -c "while true; do echo \$(date) - ${OP}ing ...; sleep $PING_SLEEP; done" &
export PING_LOOP_PID=$!

# Build command
#mvn clean install >> $OUTPUT_FILE 2>&1
xcodebuild -workspace Hammerspoon.xcworkspace -scheme Release ${XCODE_ARGS} >> $OUTPUT_FILE 2>&1

# The build finished without returning an error so dump a tail of the output
dump_output

# nicely terminate the ping output loop
kill $PING_LOOP_PID
