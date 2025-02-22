#!/bin/bash

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?"' ERR

# get the path to this script
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`

REPO_PATH=$MY_PATH/../..

## | -------------------------- args -------------------------- |

# INPUTS
LIST=$1
VARIANT=$2
REPOSITORY=$3
BASE_IMAGE=$4
DOCKER_IMAGE=$5
ARTIFACTS_FOLDER=$6

# default for testing

[ -z $LIST ] && LIST=mrs
[ -z $VARIANT ] && VARIANT=unstable
[ -z $REPOSITORY ] && REPOSITORY=mrs_lib
[ -z $BASE_IMAGE ] && BASE_IMAGE=ctumrs/ros_noetic:2025-02-05
[ -z $DOCKER_IMAGE ] && DOCKER_IMAGE=noetic_builder
[ -z $ARTIFACTS_FOLDER ] && ARTIFACTS_FOLDER=/tmp/artifacts

## | ---------------------- derived args ---------------------- |

# determine our architecture
ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

ROSDEP_FILE="generated_${LIST}_${ARCH}.yaml"

YAML_FILE=$REPO_PATH/${LIST}.yaml

# needed for building open_vins
export ROS_VERSION=1

REPOS=$($REPO_PATH/scripts/helpers/get_repo_source.py $YAML_FILE $VARIANT $ARCH $REPOSITORY)

# clone and checkout
echo "$REPOS" | while IFS= read -r REPO; do

  cd /tmp

  sudo rm -rf repository

  REPO_NAME=$(echo "$REPO" | awk '{print $1}')
  URL=$(echo "$REPO" | awk '{print $2}')
  BRANCH=$(echo "$REPO" | awk '{print $3}')
  GITMAN=$(echo "$REPO" | awk '{print $4}')

  echo "$0: cloning '$URL --depth 1 --branch $BRANCH' into '$REPO'"
  [ -e repository ] && rm -rf repository || git clone $URL --recurse-submodules --shallow-submodules --depth 1 --branch $BRANCH repository

  if [[ "$GITMAN" == "True" ]]; then
    cd repository
    pipx install gitman
    [[ -e .gitman.yml || -e .gitman.yaml ]] && gitman install
  fi

done

echo "$0: repository cloned to /tmp/repository"

## --------------------------------------------------------------
## |                        docker build                        |
## --------------------------------------------------------------

$REPO_PATH/scripts/helpers/wait_for_docker.sh

TRANSPORT_IMAGE=alpine:latest

docker buildx use default

echo "$0: loading cached builder docker image"

# docker load -i $ARTIFACTS_FOLDER/builder.tar

echo "$0: image loaded"

if [ ! -e $ARTIFACTS_FOLDER/compiled.txt ]; then
  touch $ARTIFACTS_FOLDER/compiled.txt
fi

if [ ! -e $ARTIFACTS_FOLDER/$ROSDEP_FILE ]; then
  touch $ARTIFACTS_FOLDER/$ROSDEP_FILE
fi

mkdir -p /tmp/debs
mkdir -p /tmp/other_files

cp $ARTIFACTS_FOLDER/base_sha.txt /tmp/other_files/base_sha.txt
cp $MY_PATH/entrypoint.sh /tmp/other_files/entrypoint.sh

mv $ARTIFACTS_FOLDER/compiled.txt /tmp/other_files/compiled.txt
mv $ARTIFACTS_FOLDER/$ROSDEP_FILE /tmp/other_files/rosdep.yaml

## | ---------------------- run the test ---------------------- |

docker run \
  --rm \
  -v /tmp/repository:/etc/docker/repository \
  -v /tmp/debs:/etc/docker/debs \
  -v /tmp/other_files:/etc/docker/other_files \
  $DOCKER_IMAGE \
  /bin/bash -c "/etc/docker/other_files/entrypoint.sh"

# if there are any artifacts, update the builder image

DEBS_EXIST=$(ls /tmp/debs | grep ".deb" | wc -l)

if [ $DEBS_EXIST -gt 0 ]; then

  echo "$0: updating the builder docker image"

  PASS_TO_DOCKER_BUILD="Dockerfile /tmp/debs"

  # this second build takes the resulting workspace and storest in in a final image
  # that can be deployed to a drone
  tar -czh $PASS_TO_DOCKER_BUILD 2>/dev/null | docker build - --target squash_builder --file Dockerfile --build-arg BASE_IMAGE=${BASE_IMAGE} --build-arg BUILDER_IMAGE=${DOCKER_IMAGE} --tag ${DOCKER_IMAGE} --progress plain

  echo "$0: exporting the builder docker image as ${DOCKER_IMAGE}"

  docker save ${DOCKER_IMAGE} > $ARTIFACTS_FOLDER/builder.tar

  echo "$0: copying artifacts"

  cp -r /tmp/debs/* $ARTIFACTS_FOLDER/

fi

# copy the artifacts for the next build job
mv /tmp/other_files/rosdep.yaml $ARTIFACTS_FOLDER/$ROSDEP_FILE
mv /tmp/other_files/compiled.txt $ARTIFACTS_FOLDER/compiled.txt

echo "$0: "
echo "$0: artifacts are:"

ls $ARTIFACTS_FOLDER
