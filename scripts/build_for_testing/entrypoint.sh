#!/bin/bash

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?"' ERR

# determine our architecture
ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

DEBS_FOLDER=/etc/docker/debs
OTHER_FILES_FOLDER=/etc/docker/other_files

WORKSPACE=/tmp/workspace
cd $WORKSPACE
source /opt/ros/noetic/setup.bash
catkin init

catkin config --profile debug --cmake-args -DCMAKE_BUILD_TYPE=Debug
catkin profile set debug

rosdep install -y -v --from-path src/

cd src
ln -s /etc/docker/repository

git config --global --add safe.directory /etc/docker/repository

catkin build --limit-status-rate 0.2 --cmake-args -DCOVERAGE=true -DMRS_ENABLE_TESTING=true
catkin build --limit-status-rate 0.2 --cmake-args -DCOVERAGE=true -DMRS_ENABLE_TESTING=true --catkin-make-args tests
