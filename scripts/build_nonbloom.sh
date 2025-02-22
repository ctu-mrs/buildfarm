#!/bin/bash

# get the path to this script
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?"' ERR

# get the path to this script
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`

LIST=$1
VARIANT=$2
ARCH=$3
REPOSITORY=$4
BASE_IMAGE=$5
REPOSITORY_PATH=$MY_PATH/docker_nonbloom_builder
ARTIFACTS_FOLDER=/tmp/artifacts
ARTIFACTS_FOLDER=/tmp/artifacts

YAML_FILE=${LIST}.yaml

REPO=$(./.ci/get_repo_source.py $YAML_FILE $VARIANT $ARCH $REPOSITORY)

mkdir -p $REPOSITORY_PATH
cd $REPOSITORY_PATH

PACKAGE=$(echo "$REPO" | awk '{print $1}')
URL=$(echo "$REPO" | awk '{print $2}')
BRANCH=$(echo "$REPO" | awk '{print $3}')
GITMAN=$(echo "$REPO" | awk '{print $4}')

echo "$0: cloning '$URL --depth 1 --branch $BRANCH' into '$PACKAGE'"
git clone $URL --recurse-submodules --branch $BRANCH repository

echo "$0: repository cloned"

cd repository

if [[ "$GITMAN" == "True" ]]; then
  pipx install gitman
  [[ -e .gitman.yml || -e .gitman.yaml ]] && gitman install
fi

cp -r $MY_PATH/../.ci_scripts ./

## --------------------------------------------------------------
## |                        docker build                        |
## --------------------------------------------------------------

$MY_PATH/wait_for_docker.sh

BUILDER_IMAGE=ctumrs/ros:noetic_builder
TRANSPORT_IMAGE=alpine:latest

cd $MY_PATH/docker_nonbloom_builder

docker buildx use default

echo "$0: loading cached builder docker image"

docker load -i $ARTIFACTS_FOLDER/builder.tar

echo "$0: image loaded"

[ ! -e artifacts ] && mkdir -p artifacts

cp $ARTIFACTS_FOLDER/base_sha.txt ./artifacts/base_sha.txt

PASS_TO_DOCKER_BUILD="Dockerfile artifacts build_script.sh repository"

echo "$0: running the build in the builder image for $ARCH"

# this first build compiles the contents of "src" and storest the intermediate
tar -czh $PASS_TO_DOCKER_BUILD 2>/dev/null | docker build - --target stage_export_artifacts --build-arg BUILDER_IMAGE=${BUILDER_IMAGE} --build-arg TRANSPORT_IMAGE=${TRANSPORT_IMAGE} --build-arg VARIANT=${VARIANT} --file Dockerfile --output ./cache

# copy the packages that were just built to the docker's artifacts workdir
# such that the final stage can install them
cp -r ./cache/etc/docker/artifacts/* ./artifacts

echo "$0: copying artifacts"

# copy the artifacts for the next build job
cp -r ./cache/etc/docker/artifacts/* $ARTIFACTS_FOLDER/

echo "$0: "
echo "$0: artifacts are:"

ls $ARTIFACTS_FOLDER
