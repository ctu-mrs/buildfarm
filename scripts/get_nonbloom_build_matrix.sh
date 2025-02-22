#!/bin/bash

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?, log:" && cat /tmp/log.txt' ERR

sudo apt-get -y install python3 python3-yaml >> /tmp/log.txt 2>&1

DEBUG=false

LIST=$1
VARIANT=$2
ARCH=$3

YAML_FILE=$LIST.yaml

REPOS=$(./.ci/parse_yaml.py $YAML_FILE $ARCH)

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
