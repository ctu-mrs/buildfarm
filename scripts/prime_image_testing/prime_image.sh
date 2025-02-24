#!/bin/bash

#
# ./prime_image.sh <base image> <variant>
#

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?' ERR

# get the path to this script
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`

REPO_PATH=$MY_PATH/../..

cd $MY_PATH

BASE_IMAGE=$1
OUTPUT_IMAGE=$2
PPA_VARIANT=$3
ARTIFACT_FOLDER=$4

[ -z $RUN_LOCALLY ] && RUN_LOCALLY=false

$REPO_PATH/scripts/helpers/wait_for_docker.sh

docker pull $BASE_IMAGE

docker buildx use default

if ! $RUN_LOCALLY; then

  echo "$0: logging in to docker registry"

  echo $PUSH_TOKEN | docker login ghcr.io -u ctumrsbot --password-stdin

fi

docker build . --file Dockerfile --build-arg BASE_IMAGE=${BASE_IMAGE} --build-arg PPA_VARIANT=${PPA_VARIANT} --tag ${OUTPUT_IMAGE} --progress plain

if ! $RUN_LOCALLY; then

  docker tag $OUTPUT_IMAGE ghcr.io/ctu-mrs/buildfarm:$OUTPUT_IMAGE
  docker push ghcr.io/ctu-mrs/buildfarm:$OUTPUT_IMAGE

fi
