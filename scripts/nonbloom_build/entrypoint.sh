#!/bin/bash

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?"' ERR

VARIANT=$1
ARTIFACTS_FOLDER=$2
BASE_IMAGE=$3

cd /etc/docker/repository

# call the build script within the clone repository
./.ci/build_package.sh ${VARIANT} ${ARTIFACTS_FOLDER} ${BASE_IMAGE}
