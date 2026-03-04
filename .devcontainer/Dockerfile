# DOCKER_MIRROR: 镜像加速域名，默认 docker.io（直连）
# 使用轩辕专属域名时，由 devcontainer.json 通过 MY_XY_DOMAIN_NAME 注入
ARG DOCKER_MIRROR=docker.io
FROM ${DOCKER_MIRROR}/althack/ros2:jazzy-dev

# ** [Optional] Uncomment this section to install additional packages. **
#
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
   && apt-get -y install --no-install-recommends ros-jazzy-ros-gz \
   #
   # Clean up
   && apt-get autoremove -y \
   && apt-get clean -y \
   && rm -rf /var/lib/apt/lists/*
ENV DEBIAN_FRONTEND=dialog

# Set the env variable to allow rosdep installation of pip packages
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# Set up auto-source of workspace for ros user
ARG WORKSPACE
RUN echo "if [ -f ${WORKSPACE}/install/setup.bash ]; then source ${WORKSPACE}/install/setup.bash; fi" >> /home/ros/.bashrc
