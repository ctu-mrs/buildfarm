#!/bin/bash

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?' ERR

# get the path to this script
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`

REPO_PATH=${MY_PATH}/..

DEBUG=false

## | ------------------------ arguments ----------------------- |

LIST=$1

# defaults for testing
[ -z $LIST ] && LIST=mrs

## | ----------------------------  ---------------------------- |

ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

YAML_FILE=$REPO_PATH/$LIST.yaml

REPOS=$($REPO_PATH/scripts/helpers/parse_yaml.py $YAML_FILE $ARCH)

FIRST=true

echo -n "["

echo "$REPOS" | while IFS= read -r REPO; do

  $DEBUG && echo "Cloning $REPO"

  PACKAGE=$(echo "$REPO" | awk '{print $1}')
  URL=$(echo "$REPO" | awk '{print $2}')
  TEST=$(echo "$REPO" | awk '{print $6}')

  if [[ "$TEST" != "True" ]]; then
    continue
  fi

  if $FIRST; then
    echo -n "\"$PACKAGE\""
    FIRST=false
  else
    echo -n ", \"$PACKAGE\""
  fi

done

echo "]"
