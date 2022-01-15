FROM python:3.9-buster

ARG MLPERF_VER=1.0

RUN python -m pip install --no-cache \
      numpy \
      pycocotools && \
    wget https://github.com/mlcommons/inference/archive/refs/heads/r${MLPERF_VER}.zip && \
    unzip r${MLPERF_VER}.zip && rm r${MLPERF_VER}.zip
