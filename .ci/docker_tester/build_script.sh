#!/bin/bash

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?"' ERR

WORKSPACE=/tmp/workspace
REPOSITORY_NAME=$1

if [ -e $WORKSPACE/devel ]; then

  echo "$0: workspace not initialized, initializing"

  cd $WORKSPACE

  source /opt/ros/noetic/setup.bash
  catkin init

  catkin config --profile debug --cmake-args -DCMAKE_BUILD_TYPE=Debug
  catkin profile set debug

  rosdep install -y -v --from-path src/

fi

echo "$0: building the workspace"

catkin build --limit-status-rate 0.2 --cmake-args -DCOVERAGE=true -DMRS_ENABLE_TESTING=true
catkin build --limit-status-rate 0.2 --cmake-args -DCOVERAGE=true -DMRS_ENABLE_TESTING=true --catkin-make-args tests

## set coredump generation

mkdir -p /tmp/coredump
sudo sysctl -w kernel.core_pattern="/tmp/coredump/%e_%p.core"
ulimit -c unlimited

cd $WORKSPACE/src/$REPOSITORY_NAME
ROS_DIRS=$(find . -name package.xml -printf "%h\n")

FAILED=0

for DIR in $ROS_DIRS; do
  cd $WORKSPACE/src/$REPOSITORY_NAME/$DIR
  catkin test --limit-status-rate 0.2 --this -p 1 -s || FAILED=1
done

echo "$0: tests finished"

if [[ "$FAILED" -eq 0 ]]; then

  echo "$0: storing coverage data"

  # gather all the coverage data from the workspace
  lcov --capture --directory ${WORKSPACE} --output-file /tmp/coverage.original

  # filter out unwanted files, i.e., test files
  lcov --remove /tmp/coverage.original "*/test/*" --output-file /tmp/coverage.removed || echo "$0: coverage tracefile is empty"

  # extract coverage data for the source folder of the workspace
  lcov --extract /tmp/coverage.removed "$WORKSPACE/src/*" --output-file $ARTIFACT_FOLDER/$REPOSITORY_NAME.info || echo "$0: coverage tracefile is empty"

  exit $FAILED

fi
