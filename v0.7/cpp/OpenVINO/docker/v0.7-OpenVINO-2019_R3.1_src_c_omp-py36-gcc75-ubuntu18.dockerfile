ARG OV_VER="2019_R3.1"
ARG HW_VER="c"
ARG THREAD_VER="omp"
ARG PY_VER="py36"
ARG GCC_VER="gcc75"
ARG BASEOS_VER="ubuntu18"

ARG BASE_IMAGE=provarepro/openvino:${OV_VER}_${HW_VER}_${THREAD_VER}-${PY_VER}-${GCC_VER}-${BASEOS_VER}

FROM ${BASE_IMAGE}

USER root

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHON_VERSION="3.6"

WORKDIR /

# Install Boost
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        cmake \
        build-essential \
        git \
        wget \
        libicu-dev \
        libbz2-dev \
        liblzma-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV BOOST_VERSION="1.71.0" \
    _BOOST_VERSION="1_71_0"

RUN wget -q https://boostorg.jfrog.io/artifactory/main/release/${BOOST_VERSION}/source/boost_${_BOOST_VERSION}.tar.gz && \
    tar xf boost_${_BOOST_VERSION}.tar.gz && \
    cd boost_${_BOOST_VERSION} && \
    ./bootstrap.sh --with-libraries=system && \
    ./b2 --with-system install && \
    cd / && rm -rf boost_*

# Build MLPerf loader
ARG MLPERF_LOADER_VER=r0.7
RUN python${PYTHON_VERSION} -m pip install --ignore-installed --no-cache-dir \
        absl-py \
        pybind11 && \
    git clone \
        --recurse-submodules \
        --single-branch \
        -b ${MLPERF_LOADER_VER} \
        https://github.com/mlcommons/inference.git /mlperf_inference && \
    cd /mlperf_inference && \
    mkdir loadgen/build && cd loadgen/build && \
    cmake .. && cmake --build . && \
    cp libmlperf_loadgen.a .. && \
    rm -r /mlperf_inference/loadgen/build && \
    cp -r /mlperf_inference/loadgen /mlperf_loadgen && \
    rm -rf /mlperf_inference

USER openvino
