#!/bin/bash

#!/bin/bash

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?, log:" && cat /tmp/log.txt' ERR

# get the path to this script
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`

REPO_PATH=${MY_PATH}/../..

## | ------------------------ arguments ----------------------- |

IMAGE=$1

echo $PUSH_TOKEN | docker login ghcr.io -u ctumrsbot --password-stdin
