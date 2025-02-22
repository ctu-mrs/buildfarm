ARG BUILDER_IMAGE=set_from_outside
ARG BASE_IMAGE=set_from_outside
ARG TRANSPORT_IMAGE=set_from_outside
ARG VARIANT=set_from_outside

#############################################################################

FROM $BUILDER_IMAGE AS stage_build

ARG VARIANT

COPY repository /etc/docker/repository
COPY artifacts /etc/docker/artifacts
COPY build_script.sh /etc/docker/build_script.sh

RUN git config --global --add safe.directory /etc/docker/repository

RUN ./etc/docker/build_script.sh $VARIANT

#############################################################################

FROM $TRANSPORT_IMAGE AS stage_export_artifacts

COPY --from=stage_build /etc/docker/artifacts /etc/docker/artifacts
