FROM ctumrs/ros_noetic:latest

RUN apt-get -y update

# workaround interractive prompts during apt installations
RUN echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install keyboard-configuration

# INSTALL the MRS UAV System

RUN apt-get -y install software-properties-common curl bash

RUN curl https://ctu-mrs.github.io/ppa-stable/add_ppa.sh | bash

RUN apt-get -y install ros-noetic-mrs-uav-system-full

RUN apt-get -y install gdb

# needed for UVDAR and other software utilizing graphics
RUN add-apt-repository -y ppa:kisak/kisak-mesa && sudo apt-get -y install libgbm-dev libglx-mesa0 libgl1-mesa-dri
RUN RUN apt-get -y install libgbm-dev gdb wpan-tools iproute2

CMD ["/ros_entrypoint.sh"]
