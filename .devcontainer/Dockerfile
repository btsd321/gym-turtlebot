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

# 切换 ROS 2 Jazzy apt 源为清华大学镜像
# 原始 ros2.sources 内嵌 PGP 公钥，只替换 URIs 和 Types 字段，保留 Signed-By 不变
RUN sed -i \
      -e 's|URIs: http://packages.ros.org/ros2/ubuntu|URIs: https://mirrors.tuna.tsinghua.edu.cn/ros2/ubuntu|g' \
      -e 's/Types: deb deb-src/Types: deb/g' \
    /etc/apt/sources.list.d/ros2.sources

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

# 切换 pip 源为清华大学镜像
RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple \
    && pip config set global.trusted-host pypi.tuna.tsinghua.edu.cn

# Set up auto-source of workspace for ros user
ARG WORKSPACE
RUN echo "if [ -f ${WORKSPACE}/install/setup.bash ]; then source ${WORKSPACE}/install/setup.bash; fi" >> /home/ros/.bashrc
