#!/bin/bash

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?, log:" && cat /tmp/log.txt' ERR

DEBUG=false

LIST=$1
VARIANT=$2
ARCH=$3
WORKSPACE=/tmp/workspace
ARTIFACTS_FOLDER=/tmp/artifacts

YAML_FILE=$LIST.yaml

./.ci_scripts/package_build/add_ros_ppa.sh >> /tmp/log.txt 2>&1

# dependencies need for build the deb package
sudo apt-get -y install ros-noetic-catkin python3-catkin-tools >> /tmp/log.txt 2>&1
sudo apt-get -y install fakeroot dpkg-dev debhelper >> /tmp/log.txt 2>&1
sudo pip3 install -U bloom >> /tmp/log.txt 2>&1

REPOS=$(./.ci/parse_yaml.py $YAML_FILE $ARCH)

mkdir -p $WORKSPACE >> /tmp/log.txt 2>&1
mkdir -p $ARTIFACTS_FOLDER >> /tmp/log.txt 2>&1

cd $WORKSPACE >> /tmp/log.txt 2>&1
mkdir src >> /tmp/log.txt 2>&1
source /opt/ros/noetic/setup.bash >> /tmp/log.txt 2>&1
catkin init >> /tmp/log.txt 2>&1

cd $WORKSPACE/src >> /tmp/log.txt 2>&1

# clone and checkout
echo "$REPOS" | while IFS= read -r REPO; do

  $DEBUG && echo "Cloning $REPO"

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

  echo "$0: cloning '$URL --branch $BRANCH' into '$PACKAGE'" >> /tmp/log.txt 2>&1
  git clone $URL --recurse-submodules --shallow-submodules --depth 1 --branch $BRANCH $PACKAGE >> /tmp/log.txt 2>&1
  echo "$PACKAGE" > $PACKAGE/BUILD_THIS_REPO.txt
  cd $PACKAGE >> /tmp/log.txt 2>&1

  cd $WORKSPACE/src >> /tmp/log.txt 2>&1

done

$DEBUG && echo "Done cloning"

BUILD_ORDER=$(catkin list -u)

FIRST=true

RESULT='['

$DEBUG && echo "Sorting packages"

for ROS_PACKAGE in $BUILD_ORDER; do

  cd $WORKSPACE
  PKG_PATH=$(catkin locate "$ROS_PACKAGE")
  cd $PKG_PATH

  $DEBUG && echo "Gonna look for package location for '$ROS_PACKAGE'"

  PACKAGE=""

  while true; do

    CUR_DIR=$(pwd)

    if [ -e BUILD_THIS_REPO.txt ]; then
      PACKAGE=$(cat BUILD_THIS_REPO.txt)
      rm BUILD_THIS_REPO.txt
      $DEBUG && echo "- ... found it, '$ROS_PACKAGE' originates from '$PACKAGE'"
      break
    fi

    if [[ "$CUR_DIR" == "/" ]]; then
      $DEBUG && echo "- ... did not find it, probably already on the list"
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
