#!/bin/bash

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?' ERR

# get the path to this script
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`

REPO_PATH=$MY_PATH/..

ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

LOCATION=/tmp/git

REPOS=$($REPO_PATH/scripts/helpers/parse_yaml.py mrs.yaml $ARCH)

REPOS="$REPOS
$($REPO_PATH/scripts/helpers/parse_yaml.py thirdparty.yaml $ARCH)"

REPOS="$REPOS
$($REPO_PATH/scripts/helpers/parse_yaml.py nonbloom.yaml $ARCH)"

[ -e $LOCATION ] && rm -rf $LOCATION || echo "$0: nothing to delete"
mkdir -p $LOCATION

cd $LOCATION

# clone and checkout
echo "$REPOS" | while IFS= read -r REPO; do

  echo "Cloning $REPO"

  PACKAGE=$(echo "$REPO" | awk '{print $1}')
  URL=$(echo "$REPO" | awk '{print $2}')

  # strip the https from the url
  URL=$(echo $URL | sed -r 's|https://(.+)|\1|' | head -n 1)

  RELEASE_BRANCH=$(echo "$REPO" | awk '{print $3}')
  TESTING_BRANCH=$(echo "$REPO" | awk '{print $4}')

  echo "$0: cloning '$URL --branch $RELEASE_BRANCH' into '$PACKAGE'"
  [ ! -e $PACKAGE ] && git clone https://$PUSH_TOKEN@$URL --branch $RELEASE_BRANCH $PACKAGE

  echo ""

done

echo "$0: Done cloning"
echo "$0: Going to merge and dry-run the push"

# merge and try dry-run push
echo "$REPOS" | while IFS= read -r REPO; do

  PACKAGE=$(echo "$REPO" | awk '{print $1}')
  TESTING_BRANCH=$(echo "$REPO" | awk '{print $4}')

  echo "$0: going to merge $PACKAGE"

  cd $LOCATION/$PACKAGE

  git merge origin/$TESTING_BRANCH

  git push --dry-run

  echo ""

done

echo "$0: Done merging"
echo "$0: Going to push"

# merge and try dry-run push
echo "$REPOS" | while IFS= read -r REPO; do

  PACKAGE=$(echo "$REPO" | awk '{print $1}')
  TESTING_BRANCH=$(echo "$REPO" | awk '{print $4}')

  echo "$0: going to push $PACKAGE"

  cd $LOCATION/$PACKAGE

  git push

  echo ""

done

echo "$0: Done pushing"
