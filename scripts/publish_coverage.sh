#!/bin/bash

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?"' ERR

# get the path to this script
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`

REPO_PATH=$MY_PATH/..

ARTIFACT_FOLDER=$1

[ -z $ARTIFACT_FOLDER ] && ARTIFACT_FOLDER=/tmp/artifacts

WORKSPACE=/tmp/workspace

echo "$0: extracting workspace"

# extract the workspace
cd $ARTIFACT_FOLDER
tar -xvzf workspace.tar.gz -C /tmp/

echo "$0: workspace extracted"

ls -la $WORKSPACE/src

# install lcov
sudo apt-get -y -q install lcov binutils

# are there any coverage files?

ARGS=""

for file in `ls $ARTIFACT_FOLDER | grep ".info"`; do

  if [ -s ${ARTIFACT_FOLDER}/${file} ]; then
    ARGS="${ARGS} -a ${ARTIFACT_FOLDER}/${file}"
  fi

done

lcov $ARGS --output-file /tmp/coverage_temp.info

# filter out unwanted files
lcov --remove /tmp/coverage_temp.info "*/eth_*" --output-file /tmp/coverage.info || echo "$0: coverage tracefile is empty"

genhtml --title "MRS UAV System - Test coverage report" --demangle-cpp --legend --frames --show-details -o /tmp/coverage_html /tmp/coverage.info | tee /tmp/coverage.log

COVERAGE_PCT=`cat /tmp/coverage.log | tail -n 1 | awk '{print $2}'`

echo "Coverage: $COVERAGE_PCT"

$REPO_PATH/ci_scripts/helpers/wait_for_docker.sh

docker pull klaxalk/pybadges

docker run --rm klaxalk/pybadges /bin/python3 -m pybadges --left-text="test coverage" --right-text="${COVERAGE_PCT}" --right-color="#0c0" > /tmp/coverage_html/badge.svg
