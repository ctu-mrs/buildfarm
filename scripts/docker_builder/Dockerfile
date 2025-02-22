ARG BUILDER_IMAGE=set_from_outside
ARG BASE_IMAGE=set_from_outside
ARG TRANSPORT_IMAGE=set_from_outside

#############################################################################

FROM $BUILDER_IMAGE AS stage_build

COPY repository /etc/docker/repository
COPY artifacts /etc/docker/artifacts
COPY build_script.sh /etc/docker/build_script.sh

RUN git config --global --add safe.directory /etc/docker/repository

RUN ./etc/docker/build_script.sh

#############################################################################

FROM $TRANSPORT_IMAGE AS stage_export_artifacts

COPY --from=stage_build /etc/docker/artifacts /etc/docker/artifacts

#############################################################################

FROM $BUILDER_IMAGE AS stage_update_base

RUN mkdir -p /tmp/temp_artifacts

COPY artifacts /tmp/temp_artifacts

RUN ls /tmp/temp_artifacts

RUN apt-get -y install /tmp/temp_artifacts/*.deb || echo "debs could not be installed (probably there aren't any)"

#############################################################################

FROM $BASE_IMAGE AS stage_new_builder

COPY --from=stage_update_base / /
