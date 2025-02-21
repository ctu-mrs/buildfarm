ARG BUILDER_IMAGE=set_from_outside
ARG REPOSITORY_NAME=set_from_outside

#############################################################################

FROM $BUILDER_IMAGE AS stage_test

ARG REPOSITORY_NAME

COPY workspace /tmp/workspace
COPY test_script.sh /etc/docker/test_script.sh

RUN ./etc/docker/test_script.sh $REPOSITORY_NAME
