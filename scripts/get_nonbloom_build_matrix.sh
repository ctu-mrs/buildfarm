#!/bin/bash

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?, log:" && cat /tmp/log.txt' ERR

# get the path to this script
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`

REPO_PATH=${MY_PATH}/..

DEBUG=false

## | ------------------------ arguments ----------------------- |

LIST=$1

## | ----------------------------  ---------------------------- |

ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

YAML_FILE=$REPO_PATH/$LIST.yaml

REPOS=$($REPO_PATH/scripts/helpers/parse_yaml.py $YAML_FILE $ARCH)

FIRST=true

RESULT="["

shopt -s lastpipe

# clone and checkout
echo "$REPOS" | while IFS= read -r REPO; do

  PACKAGE=$(echo "$REPO" | awk '{print $1}')

  $DEBUG && echo "$PACKAGE"

  if $FIRST; then
    RESULT=${RESULT}\"${PACKAGE}\"
    FIRST=false
  else
    RESULT="${RESULT}, \"${PACKAGE}\""
  fi

done

RESULT="${RESULT}]"

echo $RESULT
