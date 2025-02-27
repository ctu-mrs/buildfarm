#!/bin/bash

set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?"' ERR

# determine our architecture
ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

DEBS_FOLDER=/etc/docker/debs
OTHER_FILES_FOLDER=/etc/docker/other_files

WORKSPACE=/etc/docker/workspace
mkdir -p $WORKSPACE/src
cd $WORKSPACE
source /opt/ros/noetic/setup.bash
catkin init

cd src
ln -s /etc/docker/repository

git config --global --add safe.directory /etc/docker/repository

BUILD_ORDER=$(cat /etc/docker/other_files/build_order.txt)

echo ""
echo "$0: catkin reported following topological build order:"
echo "$BUILD_ORDER"
echo ""

ROSDEP_FILE=$OTHER_FILES_FOLDER/rosdep.yaml

cat $ROSDEP_FILE

if [ -s $ROSDEP_FILE ]; then

  echo "$0: adding $ROSDEP_FILE to rosdep"
  echo "$0: contents:"

  echo "yaml file://$ROSDEP_FILE" | tee /etc/ros/rosdep/sources.list.d/temp.list

  rosdep update

fi

for PACKAGE in $BUILD_ORDER; do

  PKG_PATH=$(catkin locate $PACKAGE)

  echo "$0: cding to '$PKG_PATH'"
  cd $PKG_PATH

  FUTURE_DEB_NAME=$(echo "ros-noetic-$PACKAGE" | sed 's/_/-/g')

  echo "$0: future deb name: $FUTURE_DEB_NAME"

  SHA=$(git rev-parse --short HEAD)
  DOCKER_SHA=$(cat $OTHER_FILES_FOLDER/base_sha.txt)

  echo "$0: SHA=$SHA"

  GIT_SHA_MATCHES=$(apt-cache policy $FUTURE_DEB_NAME | grep "Candidate" | grep "git.${SHA}" | wc -l)
  ON_PUSH_BUILD=$(apt-cache policy $FUTURE_DEB_NAME | grep "Candidate" | grep "on.push.build" | wc -l)
  DOCKER_SHA_MATCHES=$(apt-cache policy $FUTURE_DEB_NAME | grep "Candidate" | grep "base.${DOCKER_SHA}" | wc -l)

  NEW_COMMIT=false
  if [[ "$GIT_SHA_MATCHES" == "0" ]] || [ "$ON_PUSH_BUILD" -ge "1" ]; then
    echo "$0: new commit detected, going to compile"
    NEW_COMMIT=true
  fi

  MY_DEPENDENCIES=$(catkin list --deps --directory . -u | grep -e "^\s*-" | awk '{print $2}')

  DEPENDENCIES_CHANGED=false
  for dep in `echo $MY_DEPENDENCIES`; do

    FOUND=$(cat $OTHER_FILES_FOLDER/compiled.txt | grep $dep | wc -l)

    if [ $FOUND -ge 1 ]; then
      DEPENDENCIES_CHANGED=true
      echo "$0: The dependency $dep has been updated, going to compile"
    fi

  done

  if [[ "$DOCKER_SHA_MATCHES" == "0" ]]; then
    echo "$0: base image changed, going to compile"
    DEPENDENCIES_CHANGED=true
  fi

  if $DEPENDENCIES_CHANGED || $NEW_COMMIT; then

    ## don't run if CATKIN_IGNORE is present

    [ -e $PKG_PATH/CATKIN_IGNORE ] && continue

    apt-get -y update

    rosdep install -y -v --rosdistro=noetic --dependency-types=build --from-paths ./

    source /opt/ros/noetic/setup.bash

    echo "$0: Running bloom on a package in '$PKG_PATH'"

    if [[ "$ARCH" != "arm64" ]]; then
      export DEB_BUILD_OPTIONS="parallel=`nproc`"
    fi

    bloom-generate rosdebian --os-name ubuntu --os-version focal --ros-distro noetic

    epoch=2
    build_flag="$(date +%Y%m%d.%H%M%S)~git.$SHA.base.$DOCKER_SHA"

    sed -i "s/(/($epoch:/" ./debian/changelog
    sed -i "s/)/.${build_flag})/" ./debian/changelog

    if [[ "$ARCH" != "arm64" ]]; then
      fakeroot debian/rules "binary --parallel"
    else
      fakeroot debian/rules "binary"
    fi

    FIND_METAPACKAGE=$(cat CMakeLists.txt | grep -e "^catkin_metapackage" | wc -l)

    DEB_NAME=$(dpkg --field ../*.deb | grep "Package:" | head -n 1 | awk '{print $2}')

    DEBS=(../*.deb)

    # if [ $FIND_METAPACKAGE -eq 0 ]; then
    #
    echo "$0: installing newly compiled deb file"
    [ -e "${DEBS[0]}" ] && apt-get -y install --allow-downgrades ../*.deb || echo "$0: no artifacts to be installed"

    echo "$0: moving the artifact to $DEBS_FOLDER"
    [ -e "${DEBS[0]}" ] && mv ../*.deb $DEBS_FOLDER || echo "$0: no artifacts to be moved"

    # else
    #   echo "$0: moving the artifact to $ARTIFACTS_FOLDER/metarepositories"
    #   mkdir -p $ARTIFACTS_FOLDER/metarepositories
    #   [ -e "${DEBS[0]}" ] && mv ../*.deb $ARTIFACTS_FOLDER/metarepositories/ || echo "$0: no artifacts to be moved"
    # fi

    echo "$PACKAGE:
    ubuntu: [$DEB_NAME]
  " >> $ROSDEP_FILE

    rosdep update

    source /opt/ros/noetic/setup.bash

    echo "$PACKAGE" >> $OTHER_FILES_FOLDER/compiled.txt

  else

    echo "$0: not building this package, the newest version is already in the PPA"

    echo "$PACKAGE:
    ubuntu: [$FUTURE_DEB_NAME]
  " >> $ROSDEP_FILE

  fi

done

echo ""
echo "$0: the generated rosdep contains:"
echo ""
cat $ROSDEP_FILE
echo ""
