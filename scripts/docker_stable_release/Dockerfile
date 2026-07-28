ARG BASE_IMAGE=ctumrs/ros_noetic:latest
ARG PPA_VARIANT=stable

FROM ${BASE_IMAGE}

ARG PPA_VARIANT

# workaround interractive prompts during apt installations and install the MRS UAV System
RUN echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections && \
    apt-get update && curl https://ctu-mrs.github.io/ppa-${PPA_VARIANT}/add_ppa.sh | bash && \
    apt-get --no-install-recommends -y install ros-${ROS_DISTRO}-mrs-uav-system-full \
    gdb keyboard-configuration software-properties-common && \
    # needed for UVDAR and other software utilizing graphics
    add-apt-repository -y ppa:kisak/kisak-mesa && apt-get --no-install-recommends -y install \
    libgbm-dev libglx-mesa0 libgl1-mesa-dri wpan-tools iproute2 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

CMD ["/ros_entrypoint.sh"]
