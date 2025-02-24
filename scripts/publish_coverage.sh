#!/bin/bash

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?"' ERR

# get the path to this script
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`

REPO_PATH=$MY_PATH/..

ARTIFACT_FOLDER=$1
WORKSPACE=/tmp/workspace

# install lcov
sudo apt-get -y -q install lcov binutils

# clone the sources

LIST=mrs

ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

YAML_FILE=$LIST.yaml

REPOS=$($REPO_PATH/scripts/helpers/parse_yaml.py $YAML_FILE $ARCH)

mkdir -p $WORKSPACE/src
cd $WORKSPACE/src

echo "$REPOS" | while IFS= read -r REPO; do

PACKAGE=$(echo "$REPO" | awk '{print $1}')
URL=$(echo "$REPO" | awk '{print $2}')
TEST=$(echo "$REPO" | awk '{print $6}')

if [[ "$TEST" != "True" ]]; then
  continue
fi

git clone $URL $PACKAGE

done

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

pip install pybadges
python -m pybadges --left-text="test coverage" --right-text="${COVERAGE_PCT}" --right-color='#0c0' > /tmp/coverage_html/badge.svg
