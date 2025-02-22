#!/bin/bash

# This script will build ROS packages from a particular repository into
# deb packages
#
# INPUT:
# * ./build.sh <package list file name> <{stable/testing/unstable} variant> <repository name>
# * /tmp/artifacts containts the build artifacts from the previous jobs
# * /tmp/artifacts/idx.txt contains idx of the previous job
# * /tmp/artifacts/generated_***_***.yaml rosdep file from the previous jobs

# OUTPUT:
# * deb packages are put into the "/tmp/artifacts/$IDX" folder where $IDX is the incremented iterator of this build
# * /tmp/idx.txt with incremented value of $IDX
# * /tmp/artifacts/generated_***_***.yaml rosdep file with updated definitions from this build

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?"' ERR

VARIANT=$1
ARTIFACTS_FOLDER=/etc/docker/artifacts

cd /etc/docker/repository

# call the build script within the clone repository
./.ci/build_package.sh $VARIANT $ARTIFACTS_FOLDER
