#!/bin/bash

ARCH=amd64
LOCATION=~/git/mrs

LISTS=(
  'mrs'
  'nonbloom'
  'thirdparty'
)

for ((i=0; i < ${#LISTS[*]}; i++));
do

  LIST=${LISTS[$i]}

  YAML_FILE=$LIST.yaml

  REPOS=$(./scripts/helpers/parse_yaml.py $YAML_FILE $ARCH)

  echo $REPOS

  mkdir -p $LOCATION/$LIST

  echo "$REPOS" | while IFS= read -r REPO; do

    cd $LOCATION/$LIST

    echo "Cloning $REPO"

    PACKAGE=$(echo "$REPO" | awk '{print $1}')
    URL=$(echo "$REPO" | awk '{print $2}')
    RELEASE_CANDIDATE_BRANCH=$(echo "$REPO" | awk '{print $4}')
    UNSTABLE_BRANCH=$(echo "$REPO" | awk '{print $5}')

    if [ -e ./$PACKAGE ]; then

      echo "$0: repository '$URL' is already present, removing it"

      rm -rf ./$PACKAGE

    fi

    echo "$0: cloning '$URL --branch $BRANCH' into '$PACKAGE'"
    git clone $URL --branch $RELEASE_CANDIDATE_BRANCH $PACKAGE

    # compare the branches
    cd $PACKAGE
    git diff-index --quiet origin/$UNSTABLE_BRANCH
    retval=$?

    if [ $retval -eq 0 ]; then

      cd $LOCATION/$LIST
      echo "$0: nothing to be merged, deleting the repo"
      rm -rf ./$PACKAGE

    fi

  done

done

echo "Done cloning"

echo $RESULT
