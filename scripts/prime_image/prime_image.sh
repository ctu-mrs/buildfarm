#!/bin/bash

#
# ./prime_image.sh <base image> <output image> <variant> <artifacts folder>
#

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?' ERR

# get the path to this script
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`

REPO_PATH=$MY_PATH/../..

cd $MY_PATH

USE_REGISTRY=true

## | ------------------------ arguments ----------------------- |

BASE_IMAGE=$1
OUTPUT_IMAGE=$2
PPA_VARIANT=$3
ARTIFACTS_FOLDER=$4

# defaults for testing

[ -z $BASE_IMAGE ] && BASE_IMAGE=ctumrs/ros_noetic:2025-02-05
[ -z $OUTPUT_IMAGE ] && OUTPUT_IMAGE=noetic_builder
[ -z $PPA_VARIANT ] && PPA_VARIANT=unstable
[ -z $ARTIFACTS_FOLDER ] && ARTIFACTS_FOLDER=/tmp/artifacts

## | ---------------------- docker build ---------------------- |

echo "$0: pulling the base image"

$REPO_PATH/scripts/helpers/wait_for_docker.sh

docker pull $BASE_IMAGE

docker buildx use default

if $USE_REGISTRY; then

  echo "$0: logging in to docker registry"

  echo $PUSH_TOKEN | docker login ghcr.io -u ctumrsbot --password-stdin

fi

echo "$0: building the image"

docker build . --file Dockerfile --build-arg BASE_IMAGE=${BASE_IMAGE} --build-arg PPA_VARIANT=${PPA_VARIANT} --tag ${OUTPUT_IMAGE} --progress plain

mkdir -p $ARTIFACTS_FOLDER

echo "$0: exporting image"

if $USE_REGISTRY; then

  docker tag $OUTPUT_IMAGE ghcr.io/ctumrs/buildfarm:$OUTPUT_IMAGE
  docker push ghcr.io/ctumrs/buildfarm:$OUTPUT_IMAGE

else

  docker save $OUTPUT_IMAGE | gzip > $ARTIFACTS_FOLDER/builder.tar.gz

fi

IMAGE_SHA=$(docker inspect --format='{{index .Id}}' ${BASE_IMAGE} | head -c 15 | tail -c 8)

echo $IMAGE_SHA > $ARTIFACTS_FOLDER/base_sha.txt
