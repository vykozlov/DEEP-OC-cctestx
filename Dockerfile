# Dockerfile may have following Arguments:
# tag - tag for the Base image, (e.g. 2.9.1 for tensorflow)
# branch - user repository branch to clone (default: master, another option: test)
# jlab - if to install JupyterLab (true) or not (false)
# oneclient_ver - version of oneclient to install (e.g. 19.02.0.rc2-1~bionic)
#
# To build the image:
# $ docker build -t <dockerhub_user>/<dockerhub_repo> --build-arg arg=value .
# or using default args:
# $ docker build -t <dockerhub_user>/<dockerhub_repo> .
#
# [!] Note: For the Jenkins CI/CD pipeline, input args are defined inside the
# Jenkinsfile, not here!

ARG tag=2.9.1

# Base image, e.g. tensorflow/tensorflow:2.9.1
FROM tensorflow/tensorflow:${tag}

LABEL maintainer='V.Kozlov, Not V.Kozlov'
LABEL version='0.0.1'
# Cookiecutter test project for AI4OS / advanced branch

# What user branch to clone [!]
ARG branch=master

# Oneclient version, has to match OneData Provider and Linux version
ARG oneclient_ver=19.02.0.rc2-1~bionic

# Install Ubuntu packages
# - gcc is needed in Pytorch images because deepaas installation might break otherwise (see docs) (it is already installed in tensorflow images)
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        git \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Update python packages
# [!] Remember: DEEP API V2 only works with python>=3.6
RUN python3 --version && \
    pip3 install --no-cache-dir --upgrade pip "setuptools<60.0.0" wheel

# TODO: remove setuptools version requirement when [1] is fixed
# [1]: https://github.com/pypa/setuptools/issues/3301

# Set LANG environment
ENV LANG C.UTF-8

# Set the working directory
WORKDIR /srv

# Install rclone (needed if syncing with NextCloud for training; otherwise remove)
RUN curl -O https://downloads.rclone.org/rclone-current-linux-amd64.deb && \
    dpkg -i rclone-current-linux-amd64.deb && \
    apt install -f && \
    mkdir /srv/.rclone/ && \
    touch /srv/.rclone/rclone.conf && \
    rm rclone-current-linux-amd64.deb && \
    rm -rf /var/lib/apt/lists/*

ENV RCLONE_CONFIG=/srv/.rclone/rclone.conf

# INSTALL oneclient for ONEDATA
RUN curl -sS  http://get.onedata.org/oneclient-1902.sh  | bash -s -- oneclient="$oneclient_ver" && \
    mkdir -p /mnt/onedata && \
    rm -rf /var/lib/apt/lists/*

# Disable FLAAT authentication by default
ENV DISABLE_AUTHENTICATION_AND_ASSUME_AUTHENTICATED_USER yes

# EXPERIMENTAL: install deep-start script
# N.B.: This repository also contains run_jupyter.sh
RUN git clone https://github.com/deephdc/deep-start /srv/.deep-start && \
    ln -s /srv/.deep-start/deep-start.sh /usr/local/bin/deep-start

# Necessary for the Jupyter Lab terminal
ENV SHELL /bin/bash

# Install user app
RUN git clone -b $branch --depth 1 https://github.com/vykozlov/cctestx && \
    cd  cctestx && \
    pip3 install --no-cache-dir -e . && \
    cd ..

# Open ports: DEEPaaS (5000), Monitoring (6006), Jupyter (8888)
EXPOSE 5000 6006 8888

# Launch deepaas
CMD ["deep-start","--deepaas"]
