# DOCKER_MIRROR: 镜像加速域名，默认 docker.io（直连）
# 使用轩辕专属域名时，由 devcontainer.json 通过 MY_XY_DOMAIN_NAME 注入
ARG DOCKER_MIRROR=docker.io
FROM ${DOCKER_MIRROR}/althack/ros2:jazzy-dev

# ** [Optional] Uncomment this section to install additional packages. **
#
ENV DEBIAN_FRONTEND=noninteractive

# 切换 Ubuntu 24.04 (Noble) apt 源为清华大学镜像
RUN sed -i 's|http://archive.ubuntu.com/ubuntu|https://mirrors.tuna.tsinghua.edu.cn/ubuntu|g' /etc/apt/sources.list.d/ubuntu.sources \
   && sed -i 's|http://security.ubuntu.com/ubuntu|https://mirrors.tuna.tsinghua.edu.cn/ubuntu|g' /etc/apt/sources.list.d/ubuntu.sources

# 切换 ROS 2 Jazzy apt 源为清华大学镜像，并移除 deb-src（清华镜像无源码包索引）
# 同时兼容 .list 格式（行首 deb-src）和 DEB822 .sources 格式（Types: deb deb-src）
RUN find /etc/apt/sources.list.d/ \( -name "*.list" -o -name "*.sources" \) -exec \
      sed -i \
        -e 's|http://packages.ros.org/ros2/ubuntu|https://mirrors.tuna.tsinghua.edu.cn/ros2/ubuntu|g' \
        -e '/^deb-src/d' \
        -e 's/Types: deb deb-src/Types: deb/g' \
        -e 's/Types: deb-src deb/Types: deb/g' \
        -e 's/^Types: deb-src$/Types: deb/g' \
      {} +

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
