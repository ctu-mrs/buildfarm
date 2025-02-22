#!/bin/bash

#
# ./run_tests.sh <repository list> <variant> <repository>
#

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?"' ERR

# get the path to this script
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`

REPO_PATH=${MY_PATH}/../..

# determine our architecture
ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

## | ------------------------ arguments----------------------- |

LIST=$1
VARIANT=$2
REPOSITORY_NAME=$3
DOCKER_IMAGE=$4

# defaults for testing

if [ -z $LIST ]; then
  LIST=mrs
fi

if [ -z $VARIANT ]; then
  VARIANT=unstable
fi

if [ -z $REPOSITORY_NAME ]; then
  REPOSITORY_NAME=mrs_lib
fi

if [ -z $DOCKER_IMAGE ]; then
  DOCKER_IMAGE=noetic_builder
fi

## | -------------------- derived variables ------------------- |

YAML_FILE=${REPO_PATH}/${LIST}.yaml

ARTIFACTS_FOLDER=/tmp/artifacts
WORKSPACE_FOLDER=/tmp/workspace

## --------------------------------------------------------------
## |                  prepare the tester image                  |
## --------------------------------------------------------------

$REPO_PATH/scripts/helpers/wait_for_docker.sh

docker buildx use default

echo "$0: loading cached builder docker image"

docker load -i $ARTIFACTS_FOLDER/builder.tar

echo "$0: image loaded"

## --------------------------------------------------------------
## |                    prepare the workspace                   |
## --------------------------------------------------------------

mkdir -p $WORKSPACE_FOLDER

if [ -e $ARTIFACT_FOLDER/workspace.tar.gz ]; then

  echo "$0: workspace passed from the job before"

  mv $ARTIFACT_FOLDER/workspace.tar.gz $WORKSPACE_FOLDER
  cd $WORKSPACE_FOLDER
  tar -xvzf workspace.tar.gz

else

  echo "$0: creating the workspace"

  mkdir -p $WORKSPACE_FOLDER/src

fi

## | ---------------- clone the tested package ---------------- |

echo "$0: cloning the package"

THIS_TEST_REPOS=$($REPO_PATH/scripts/helpers/get_repo_source.py $YAML_FILE $VARIANT $ARCH $REPOSITORY_NAME)

echo "$THIS_TEST_REPOS" | while IFS= read -r REPO; do

  cd $WORKSPACE_FOLDER/src

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

done

## | ----------------- copy the testing script ---------------- |

cp $MY_PATH/entrypoint.sh $WORKSPACE_FOLDER/

## | -------------------- enable core dumps ------------------- |

sudo sysctl -w kernel.core_pattern="/tmp/coredumps/%e_%p.core"
ulimit -c unlimited

## | ---------------------- run the test ---------------------- |

docker run \
  --rm \
  -v $WORKSPACE_FOLDER:/etc/docker/workspace \
  -v /tmp/coredumps:/etc/docker/coredumps \
  -v /tmp/coverage:/etc/docker/coverage \
  $DOCKER_IMAGE \
  /bin/bash -c "/etc/docker/workspace/entrypoint.sh $REPOSITORY_NAME"
