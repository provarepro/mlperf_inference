ARG TF_VER="v2.3.0"
ARG HW_VER="c"
ARG THREAD_VER="omp"
ARG PY_VER="py38"
ARG GCC_VER="gcc93"
ARG BASEOS_VER="ubuntu20"

ARG BASE_IMAGE=provarepro/tensorflow:${TF_VER}-${PY_VER}-${GCC_VER}-${BASEOS_VER}_v2
#ARG BASE_IMAGE=provarepro/openvino:${OV_VER}_${HW_VER}_${THREAD_VER}-${PY_VER}-${GCC_VER}-${BASEOS_VER}

FROM ${BASE_IMAGE}

USER root

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHON_VERSION="3.8"

WORKDIR /

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        numactl \
        libtcmalloc-minimal4 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ARG LOADER_VER=0.5a0
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

ENV LD_LIBRARY_PATH=/deps-installation/tf-cc/lib:/opt/opencv/lib:/opt/boost/1_74_0/lib:$LD_LIBRARY_PATH
