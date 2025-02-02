#!/bin/bash

# get the path to this script
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?, log:" && cat /tmp/log.txt' ERR

LIST=$1
VARIANT=$2
ARCH=$3
WORKSPACE=/tmp/workspace

YAML_FILE=$LIST.yaml

REPOS=$($MY_PATH/parse_yaml.py $YAML_FILE $ARCH)

if [ -e $WORKSPACE ]; then
  rm -rf $WORKSPACE
fi

mkdir -p $WORKSPACE/src >> /tmp/log.txt 2>&1

cd $WORKSPACE >> /tmp/log.txt 2>&1

cd $WORKSPACE/src >> /tmp/log.txt 2>&1

# clone and checkout
echo "$REPOS" | while IFS= read -r REPO; do

  PACKAGE=$(echo "$REPO" | awk '{print $1}')
  URL=$(echo "$REPO" | awk '{print $2}')

  if [[ "$VARIANT" == "stable" ]]; then
    BRANCH=$(echo "$REPO" | awk '{print $3}')
  elif [[ "$VARIANT" == "testing" ]]; then
    BRANCH=$(echo "$REPO" | awk '{print $4}')
  else
    BRANCH=$(echo "$REPO" | awk '{print $5}')
  fi

  if [[ "$BRANCH" == "none" ]]; then
    continue
  fi

  echo "$0: Cloning '$REPO' from '$URL --branch $BRANCH' into '$PACKAGE'" >> /tmp/log.txt 2>&1

  git clone $URL --recurse-submodules --shallow-submodules --depth 1 --branch $BRANCH $PACKAGE >> /tmp/log.txt 2>&1
  echo "$PACKAGE" > $PACKAGE/BUILD_THIS_REPO.txt
  cd $PACKAGE >> /tmp/log.txt 2>&1

  cd $WORKSPACE/src >> /tmp/log.txt 2>&1

done

echo "$0: Done cloning" >> /tmp/log.txt 2>&1
echo "" >> /tmp/log.txt 2>&1

BUILD_ORDER=$($MY_PATH/get_build_order.py $WORKSPACE/src)

echo "$0: ROS package build order:" >> /tmp/log.txt 2>&1
echo "$BUILD_ORDER" >> /tmp/log.txt 2>&1
echo "" >> /tmp/log.txt 2>&1

FIRST=true

RESULT='['

echo "" >> /tmp/log.txt 2>&1
echo "$0: Sorting packages" >> /tmp/log.txt 2>&1

for PKG_PATH in $BUILD_ORDER; do

  cd $WORKSPACE/src/$PKG_PATH

  echo "$0: Gonna look for package location for '$PKG_PATH'" >> /tmp/log.txt 2>&1

  PACKAGE=""

  while true; do

    CUR_DIR=$(pwd)

    if [ -e BUILD_THIS_REPO.txt ]; then
      PACKAGE=$(cat BUILD_THIS_REPO.txt)
      rm BUILD_THIS_REPO.txt
      echo "$0: - ... found it, '$PKG_PATH' originates from '$PACKAGE'" >> /tmp/log.txt 2>&1
      break
    fi

    if [[ "$CUR_DIR" == "/" ]]; then
      echo "$0: - ... did not find it, probably already on the list" >> /tmp/log.txt 2>&1
      break
    fi

    cd ..
  done

  if [ ! -z $PACKAGE ]; then

    if $FIRST; then
      RESULT=$RESULT\"$PACKAGE\"
      FIRST=false
    else
      RESULT="$RESULT, \"$PACKAGE\""
    fi
  fi

done

RESULT="$RESULT]"

echo $RESULT
