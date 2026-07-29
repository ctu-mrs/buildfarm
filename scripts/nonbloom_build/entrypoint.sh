#!/bin/bash

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?"' ERR

ARTIFACTS_FOLDER=$1
BASE_IMAGE=$2

cd /etc/docker/repository

git config --global --add safe.directory /etc/docker/repository

apt-get -o Acquire::Retries=4 update

# call the build script within the clone repository
./.ci/build_package.sh ${ARTIFACTS_FOLDER} ${BASE_IMAGE}
