#!/bin/bash

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?' ERR

# get the path to this script
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`

cd $MY_PATH

BASE_IMAGE=$1
PPA_VARIANT=$2

# docker login --username klaxalk --password $TOKEN

docker pull $BASE_IMAGE

docker buildx use default

docker build . --file Dockerfile --build-arg BASE_IMAGE=${BASE_IMAGE} --build-arg PPA_VARIANT=${PPA_VARIANT} --tag ctumrs/ros:noetic_builder --progress plain

# docker push ctumrs/ros:noetic_builder

docker save ctumrs/ros:noetic_builder > /tmp/artifacts/builder.tar

IMAGE_SHA=$(docker inspect --format='{{index .Id}}' ${BASE_IMAGE} | head -c 15 | tail -c 8)

echo $IMAGE_SHA > /tmp/artifacts/base_sha.txt
