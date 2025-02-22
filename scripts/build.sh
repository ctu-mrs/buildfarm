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

# get the path to this script
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`

# determine our architecture
ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

# INPUTS
LIST=$1
VARIANT=$2
REPOSITORY=$3
BASE_IMAGE=$4
REPOSITORY_PATH=$MY_PATH/docker_builder
ARTIFACTS_FOLDER=/tmp/artifacts
ROSDEP_FILE="generated_${LIST}_${ARCH}.yaml"

YAML_FILE=${LIST}.yaml

# needed for building open_vins
export ROS_VERSION=1

REPOS=$(./.ci/get_repo_source.py $YAML_FILE $VARIANT $ARCH $REPOSITORY)

mkdir -p $REPOSITORY_PATH
cd $REPOSITORY_PATH

# clone and checkout
echo "$REPOS" | while IFS= read -r REPO; do

  REPO_NAME=$(echo "$REPO" | awk '{print $1}')
  URL=$(echo "$REPO" | awk '{print $2}')
  BRANCH=$(echo "$REPO" | awk '{print $3}')
  GITMAN=$(echo "$REPO" | awk '{print $4}')

  echo "$0: cloning '$URL --depth 1 --branch $BRANCH' into '$REPO'"
  git clone $URL --recurse-submodules --shallow-submodules --depth 1 --branch $BRANCH repository
  git config --global --add safe.directory $REPOSITORY_PATH/repository

  if [[ "$GITMAN" == "True" ]]; then
    cd repository
    pipx install gitman
    [[ -e .gitman.yml || -e .gitman.yaml ]] && gitman install
  fi

done

echo "$0: repository cloned"

## --------------------------------------------------------------
## |                        docker build                        |
## --------------------------------------------------------------

$MY_PATH/wait_for_docker.sh

BUILDER_IMAGE=ctumrs/ros:noetic_builder
TRANSPORT_IMAGE=alpine:latest

REPOSITORY_PATH=./repository
ARTIFACTS_PATH=./artifacts

cd $MY_PATH/docker_builder

docker buildx use default

echo "$0: loading cached builder docker image"

# docker login --username klaxalk --password $TOKEN

# docker pull $BUILDER_IMAGE

docker load -i $ARTIFACTS_FOLDER/builder.tar

echo "$0: image loaded"

[ ! -e artifacts ] && mkdir -p artifacts

if [ -e $ARTIFACTS_FOLDER/compiled.txt ]; then
  mv $ARTIFACTS_FOLDER/compiled.txt ./artifacts/compiled.txt
else
  touch ./artifacts/compiled.txt
fi

if [ -e $ARTIFACTS_FOLDER/$ROSDEP_FILE ]; then
  mv $ARTIFACTS_FOLDER/$ROSDEP_FILE ./artifacts/rosdep.yaml
else
  touch ./artifacts/rosdep.yaml
fi

cp $ARTIFACTS_FOLDER/base_sha.txt ./artifacts/base_sha.txt

PASS_TO_DOCKER_BUILD="Dockerfile artifacts build_script.sh repository"

echo "$0: running the build in the builder image for $ARCH"

# this first build compiles the contents of "src" and storest the intermediate
tar -czh $PASS_TO_DOCKER_BUILD 2>/dev/null | docker build - --target stage_export_artifacts --build-arg BUILDER_IMAGE=${BUILDER_IMAGE} --build-arg TRANSPORT_IMAGE=${TRANSPORT_IMAGE} --file Dockerfile --output ./cache

echo "$0: updating the base image"

PASS_TO_DOCKER_BUILD="Dockerfile artifacts"

# copy the packages that were just built to the docker's artifacts workdir
# such that the final stage can install them
cp -r ./cache/etc/docker/artifacts/* ./artifacts

echo "$0: updating the builder docker image"

# this second build takes the resulting workspace and storest in in a final image
# that can be deployed to a drone
tar -czh $PASS_TO_DOCKER_BUILD 2>/dev/null | docker build - --target stage_new_builder --file Dockerfile --build-arg BASE_IMAGE=${BASE_IMAGE} --build-arg BUILDER_IMAGE=${BUILDER_IMAGE} --tag ${BUILDER_IMAGE}

echo "$0: inspecting resulting image"

docker history ${BUILDER_IMAGE}

echo "$0: copying artifacts"

# copy the artifacts for the next build job
cp -r ./cache/etc/docker/artifacts/* $ARTIFACTS_FOLDER/
mv $ARTIFACTS_FOLDER/rosdep.yaml $ARTIFACTS_FOLDER/$ROSDEP_FILE

echo "$0: "
echo "$0: artifacts are:"

ls $ARTIFACTS_FOLDER

echo "$0: "
echo "$0: exporting the builder docker image as ${BUILDER_IMAGE}"

# docker push ${BUILDER_IMAGE}

docker save ${BUILDER_IMAGE} > $ARTIFACTS_FOLDER/builder.tar
