ARG OV_VER_BUILD="2019_R3.1"
ARG OV_VER_BASE="2019_pre-release"
ARG HW_VER="c"
ARG THREAD_VER="tbb"
ARG PY_VER="py36"
ARG GCC_VER="gcc75"
ARG BASEOS_VER="ubuntu18"

ARG BASE_IMAGE=provarepro/openvino:${OV_VER_BASE}_${HW_VER}_${THREAD_VER}-${PY_VER}-${GCC_VER}-${BASEOS_VER}

FROM openvino/${BASEOS_VER}_dev:${OV_VER_BUILD} as builder

WORKDIR /tmp

RUN curl -O https://zenodo.org/record/3401714/files/ssd_mobilenet_v1_quant_ft_no_zero_point_frozen_inference_graph.pb && \
    curl -O https://zenodo.org/record/3252084/files/mobilenet_v1_ssd_8bit_finetuned.tar.gz && \
    tar xf mobilenet_v1_ssd_8bit_finetuned.tar.gz && \
    rm mobilenet_v1_ssd_8bit_finetuned.tar.gz && \
    cp mobilenet_v1_ssd_finetuned/pipeline.config . && \
    rm -rf mobilenet_v1_ssd_finetuned && \
    python3 /opt/intel/openvino/deployment_tools/model_optimizer/mo.py \
        --input_model /tmp/ssd_mobilenet_v1_quant_ft_no_zero_point_frozen_inference_graph.pb \
        --input_shape [1,300,300,3] \
        --tensorflow_use_custom_operations_config /opt/intel/openvino/deployment_tools/model_optimizer/extensions/front/tf/ssd_v2_support.json \
        --tensorflow_object_detection_api_pipeline_config /tmp/pipeline.config

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

RUN python${PYTHON_VERSION} -m pip install --ignore-installed --no-cache-dir \
        absl-py \
        pybind11 && \
    git clone \
        --recurse-submodules \
        --single-branch \
        -b r0.5 \
        https://github.com/mlcommons/inference.git /mlperf_inference && \
    cd /mlperf_inference && \
    git config --global user.email "antonio.maffia@gmail.com" && \
    git config --global user.name "fenz" && \
    git pull --no-commit --force origin pull/502/head && \
    git pull --no-commit origin pull/482/head && \
    git commit -m "merge PRs" && \
    mkdir loadgen/build && cd loadgen/build && \
    cmake .. && cmake --build . && \
    cp libmlperf_loadgen.a .. && \
    rm -r /mlperf_inference/loadgen/build && \
    cp -r /mlperf_inference/loadgen /mlperf_loadgen && \
    rm -rf /mlperf_inference

RUN CODE_PATH="closed/Intel/code/ssd-small/openvino-linux" && \
    git clone \
        --depth 1 \
        -b code \
        --single-branch \
        https://github.com/fenz-org/mlperf_inference_results_v0.5.git inference_results_v0.5 && \
    mv inference_results_v0.5/${CODE_PATH} /mlperf_inference && \
    rm -rf inference_results_v0.5

WORKDIR /mlperf_inference

RUN mkdir build && cd build && \
    cmake \
        -DLOADGEN_DIR=/mlperf_loadgen \
        -DIE_SRC_DIR=${InferenceEngine_DIR}/../src \
        -DBOOST_SYSTEM_LIB=/usr/local/lib/libboost_system.so \
        -DCMAKE_BUILD_TYPE=Release \
        .. && \
    cmake --build . --config Release

COPY --from=builder \
         /tmp/ssd_mobilenet_v1_quant_ft_no_zero_point_frozen_inference_graph.xml \
         /mlperf_inference/model/ssd-mobilenet.xml

COPY --from=builder \
         /tmp/ssd_mobilenet_v1_quant_ft_no_zero_point_frozen_inference_graph.bin \
         /mlperf_inference/model/ssd-mobilenet.bin

COPY --from=builder \
         /tmp/ssd_mobilenet_v1_quant_ft_no_zero_point_frozen_inference_graph.mapping \
         /mlperf_inference/model/ssd-mobilenet.mapping

USER openvino
