#!/bin/bash

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?' ERR

# get the path to this script
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`

cd $MY_PATH

## | ------------------ check if rebuild needed ----------------- |

[ -z $RUN_LOCALLY ] && RUN_LOCALLY=false

NEED_REBUILD=false

if $RUN_LOCALLY || [[ "${GITHUB_EVENT_NAME:-}" == "workflow_dispatch" ]]; then
  echo "$0: Manual build requested, going to build"
  NEED_REBUILD=true
elif [[ "$(date +%u)" == [67] ]]; then
  echo "$0: Weekend run - triggering weekly full rebuild for updated toolchains and base images"
  NEED_REBUILD=true
else
  HUB_TAG_INFO=$(curl -s "https://hub.docker.com/v2/repositories/ctumrs/mrs_uav_system/tags/latest")
  IMAGE_PUSHED_AT=$(echo "$HUB_TAG_INFO" | jq -r .tag_last_pushed 2>/dev/null || true)

  if [ -z "$IMAGE_PUSHED_AT" ] || [ "$IMAGE_PUSHED_AT" = "null" ]; then
    echo "$0: Image ctumrs/mrs_uav_system:latest not found on Docker Hub, going to build"
    NEED_REBUILD=true
  else
    IMAGE_TIME=$(date -d "$IMAGE_PUSHED_AT" +%s 2>/dev/null || echo 0)
    REPO_TIME=$(git log -1 --format=%ct)

    if [ "$REPO_TIME" -gt "$IMAGE_TIME" ]; then
      echo "$0: Repository has newer commit ($REPO_TIME > $IMAGE_TIME), going to build"
      NEED_REBUILD=true
    fi

    AUTH_HEADER=()
    if [ -n "${PUSH_TOKEN:-}" ]; then
      AUTH_HEADER=(-H "Authorization: token $PUSH_TOKEN")
    fi
    PPA_COMMITS=$(curl -s "${AUTH_HEADER[@]}" "https://api.github.com/repos/ctu-mrs/ppa-stable/commits/debs")
    PPA_DATE=$(echo "$PPA_COMMITS" | jq -r .commit.committer.date 2>/dev/null || true)
    if [ -n "$PPA_DATE" ] && [ "$PPA_DATE" != "null" ]; then
      PPA_TIME=$(date -d "$PPA_DATE" +%s 2>/dev/null || echo 0)
      if [ "$PPA_TIME" -gt "$IMAGE_TIME" ]; then
        echo "$0: PPA ppa-stable updated ($PPA_TIME > $IMAGE_TIME), going to build"
        NEED_REBUILD=true
      fi
    fi
  fi
fi

if ! $NEED_REBUILD; then
  echo "$0: Image ctumrs/mrs_uav_system:latest is up to date (last pushed at $IMAGE_PUSHED_AT). Skipping."
  exit 0
fi

## | ------------------------ docker build ---------------------- |

docker login --username klaxalk --password $TOKEN

docker buildx create --name container --driver=docker-container --use

docker buildx build . --file Dockerfile --tag ctumrs/mrs_uav_system:latest --platform=linux/amd64,linux/arm64 --push 
