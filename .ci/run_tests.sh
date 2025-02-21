#!/bin/bash

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
REPOSITORY_NAME=$3
REPOSITORY_PATH=$MY_PATH/docker_builder
ARTIFACTS_FOLDER=/tmp/artifacts

if [ -e $ARTIFACT_FOLDER/workspace.tar.gz ]; then

  mv $ARTIFACT_FOLDER/workspace.tar.gz $MY_PATH/docker_tester/
  cd $MY_PATH/docker_tester/
  tar -xvzf workspace.tar.gz

else

  mkdir -p $MY_PATH/docker_tester/workspace

fi

## | ---------------- clone the tested package ---------------- |

echo "$0: cloning the package"

THIS_TEST_REPOS=$(./.ci/get_repo_source.py $YAML_FILE $VARIANT $ARCH $REPOSITORY_NAME)

# clone and checkout
echo "$THIS_TEST_REPOS" | while IFS= read -r REPO; do

cd $WORKSPACE/src

PACKAGE=$(echo "$REPO" | awk '{print $1}')
URL=$(echo "$REPO" | awk '{print $2}')
BRANCH=$(echo "$REPO" | awk '{print $3}')
GITMAN=$(echo "$REPO" | awk '{print $4}')

[ ! -e ${PACKAGE} ] && echo "$0: cloning '$URL --depth 1 --branch $BRANCH' into '$PACKAGE'" || echo "$0: not cloning, already there"
[ ! -e ${PACKAGE} ] && git clone $URL --recurse-submodules --shallow-submodules --depth 1 --branch $BRANCH $PACKAGE || echo "$0: not cloning, already there"

if [[ "$GITMAN" == "True" ]]; then
  cd $PACKAGE
  [[ -e .gitman.yml || -e .gitman.yaml ]] && gitman install || echo "no gitman modules to install"
fi

echo "$0: repository cloned"

## --------------------------------------------------------------
## |                        docker build                        |
## --------------------------------------------------------------

$MY_PATH/wait_for_docker.sh

BUILDER_IMAGE=ctumrs/ros:noetic_builder
TRANSPORT_IMAGE=alpine:latest

REPOSITORY_PATH=./repository
ARTIFACTS_PATH=./artifacts

cd $MY_PATH/docker_tester

docker buildx use default

echo "$0: loading cached builder docker image"

docker load -i $ARTIFACTS_FOLDER/builder.tar

echo "$0: image loaded"

PASS_TO_DOCKER_BUILD="Dockerfile workspace test_script.sh"

echo "$0: running the build in the builder image for $ARCH"

# this first build compiles the contents of "src" and storest the intermediate
tar -czh $PASS_TO_DOCKER_BUILD 2>/dev/null | docker build - --target stage_test --build-arg BUILDER_IMAGE=${BUILDER_IMAGE} --build-arg REPOSITORY_NAME=${REPOSITORY_NAME} --file Dockerfile
