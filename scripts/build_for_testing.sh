#!/bin/bash

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?"' ERR

LIST=mrs
ARTIFACT_FOLDER=$1
VARIANT=$2
WORKSPACE=/tmp/workspace

YAML_FILE=${LIST}.yaml

# needed for building open_vins
export ROS_VERSION=1

sudo apt-get -y install dpkg-dev

ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

if [[ "$ARCH" != "arm64" ]]; then
  curl https://ctu-mrs.github.io/ppa-$VARIANT/add_ros_ppa.sh | bash
fi

curl https://ctu-mrs.github.io/ppa-$VARIANT/add_ppa.sh | bash

sudo apt-get -y -q install ros-noetic-desktop
sudo apt-get -y -q install ros-noetic-mrs-uav-system
sudo apt-get -y -q install lcov

sudo apt-get -y install python3-catkin-tools
sudo pip3 install -U gitman

FULL_COVERAGE_REPOS=$(./.ci/parse_yaml.py $YAML_FILE $ARCH)

echo "$0: creating workspace"

mkdir -p $WORKSPACE/src
cd $WORKSPACE
source /opt/ros/noetic/setup.bash
catkin init

catkin config --profile debug --cmake-args -DCMAKE_BUILD_TYPE=Debug
catkin profile set debug

## | ------- clone other packages for full test coverage ------ |

echo "$FULL_COVERAGE_REPOS" | while IFS= read -r REPO; do

  cd $WORKSPACE/src

  PACKAGE=$(echo "$REPO" | awk '{print $1}')
  URL=$(echo "$REPO" | awk '{print $2}')
  TEST=$(echo "$REPO" | awk '{print $6}')
  FULL_COVERAGE=$(echo "$REPO" | awk '{print $7}')
  GITMAN=$(echo "$REPO" | awk '{print $8}')

  if [[ "$VARIANT" == "stable" ]]; then
    BRANCH=$(echo "$REPO" | awk '{print $3}')
  elif [[ "$VARIANT" == "testing" ]]; then
    BRANCH=$(echo "$REPO" | awk '{print $4}')
  elif [[ "$VARIANT" == "unstable" ]]; then
    BRANCH=$(echo "$REPO" | awk '{print $5}')
  fi

  if [[ "$TEST" != "True" ]]; then
    continue
  fi

  if [[ "$FULL_COVERAGE" != "True" ]]; then
    continue
  fi

  if [[ "$PACKAGE" == "$REPOSITORY_NAME" ]]; then
    continue
  fi

  echo "$0: cloning '$URL --depth 1 --branch $BRANCH' into '$PACKAGE'"
  git clone $URL --recurse-submodules --shallow-submodules --depth 1 --branch $BRANCH $PACKAGE

  if [[ "$GITMAN" == "True" ]]; then
    cd $PACKAGE
    [[ -e .gitman.yml || -e .gitman.yaml ]] && gitman install
  fi

done

cd $WORKSPACE/src

echo "$0: installing rosdep dependencies"

rosdep install -y --from-path .

echo "$0: building the workspace"

catkin build --limit-status-rate 0.2 --cmake-args -DCOVERAGE=true -DMRS_ENABLE_TESTING=true
catkin build --limit-status-rate 0.2 --cmake-args -DCOVERAGE=true -DMRS_ENABLE_TESTING=true --catkin-make-args tests

echo "$0: tar the workspace"

cd /tmp
tar -cvzf workspace.tar.gz workspace
mv workspace.tar.gz $ARTIFACT_FOLDER/
