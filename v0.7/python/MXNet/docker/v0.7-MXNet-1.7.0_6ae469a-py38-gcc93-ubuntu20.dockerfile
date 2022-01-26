ARG BASE_IMAGE=ubuntu:20.04

FROM ${BASE_IMAGE}

USER root

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHON_VERSION="3.8"

WORKDIR /tmp

# Intall Python
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        build-essential \
        curl \
        wget \
        unzip \
        ca-certificates \
        sudo \
        python${PYTHON_VERSION}-dev \
        python${PYTHON_VERSION}-distutils \
        python3-pip \
        g++ \
        libopencv-dev \
        protobuf-compiler \
        libprotoc-dev \
        python3-opencv && \
    cd /usr/bin && \
    ln -s python${PYTHON_VERSION} python && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install MKL
ADD https://raw.githubusercontent.com/intel/oneapi-containers/master/images/docker/basekit/third-party-programs.txt /third-party-programs.txt

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gpg-agent \
        software-properties-common && \
  rm -rf /var/lib/apt/lists/*
# repository to install Intel(R) oneAPI Libraries
RUN curl -fsSL https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS-2019.PUB | apt-key add -
RUN echo "deb [trusted=yes] https://apt.repos.intel.com/mkl all main " > /etc/apt/sources.list.d/intel-mkl.list

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        intel-mkl-2019.5-075 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV LD_LIBRARY_PATH=/opt/intel/lib/intel64_lin:$LD_LIBRARY_PATH

# Install MXNet
RUN python${PYTHON_VERSION} -m pip install --ignore-installed --no-cache-dir \
        cmake && \
    git clone https://github.com/apache/incubator-mxnet.git && \
    cd incubator-mxnet && \
    git checkout 6ae469a17ebe517325cdf6acdf0e2a8b4d464734 && \
    git submodule update --init && \
    make -j 2 \
        USE_OPENCV=0 \
        USE_MKLDNN=1 \
        USE_BLAS=mkl \
        USE_PROFILER=0 \
        USE_LAPACK=0 \
        USE_GPERFTOOLS=0 \
        USE_INTEL_PATH=/opt/intel/ && \
    cd python && \
    python setup.py install

# Install ONNX
RUN python${PYTHON_VERSION} -m pip install --ignore-installed --no-cache-dir \
        onnx \
        opencv-python \
        pycocotools \
        onnxruntime

# Build MLPerf loader
ARG LOADER_VER=0.5a0
ARG MLPERF_LOADER_VER=r0.7
RUN python${PYTHON_VERSION} -m pip install --ignore-installed --no-cache-dir \
        absl-py \
        pybind11 && \
    git clone \
        --recurse-submodules \
        --depth 1 \
        --single-branch \
        -b ${MLPERF_LOADER_VER} \
        https://github.com/mlcommons/inference.git /mlperf_inference && \
    cd /mlperf_inference/loadgen && \
    CFLAGS="-std=c++14 -O3" python setup.py bdist_wheel && \
    python -m pip install \
        dist/mlperf_loadgen-${LOADER_VER}-*.whl && \
    rm dist/mlperf_loadgen-${LOADER_VER}-*.whl && \
    rm -rf /mlperf_inference

RUN git clone https://github.com/mlcommons/inference_results_v0.7.git mlperf-inf-res && \
    mv mlperf-inf-res/closed/Intel/code/resnet/resnet-mx /mlperf_inference && \
    cd /mlperf_inference && \
    mkdir model && \
    wget -O ./model/resnet50-v1.5.onnx https://zenodo.org/record/2592612/files/resnet50_v1.onnx && \
    python3 tools/onnx2mxnet.py

RUN git clone https://github.com/intel/lp-opt-tool && \
    cp /mlperf_inference/ilit_calib.patch lp-opt-tool/ && \
    cd lp-opt-tool && \
    git checkout c468259 && \
    git apply ilit_calib.patch && \
    python setup.py install

