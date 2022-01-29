ARG BASE_IMAGE=provarepro/mxnet:1.7.0-py38-gcc93-ubuntu20

FROM ${BASE_IMAGE} as builder

USER root

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ARG DEBIAN_FRONTEND=noninteractive \
    PYTHON_VERSION="3.8"

WORKDIR /tmp

# Install ONNX
RUN python${PYTHON_VERSION} -m pip install --ignore-installed --no-cache-dir \
        onnx \
        opencv-python \
        pycocotools \
        onnxruntime

RUN git clone https://github.com/mlcommons/inference_results_v0.7.git mlperf-inf-res && \
    mv mlperf-inf-res/closed/Intel/code/resnet/resnet-mx /mlperf_inference && \
    cd /mlperf_inference && \
    mkdir model && \
    cd model && \
    curl -O https://zenodo.org/record/2592612/files/resnet50_v1.onnx && \
    cd - && \
    python3 tools/onnx2mxnet.py

FROM ${BASE_IMAGE}

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
    python -m pip install --ignore-installed --no-cache-dir \
        dist/mlperf_loadgen-${LOADER_VER}-*.whl && \
    rm dist/mlperf_loadgen-${LOADER_VER}-*.whl && \
    rm -rf /mlperf_inference

COPY --from=builder /mlperf_inference /mlperf_inference
