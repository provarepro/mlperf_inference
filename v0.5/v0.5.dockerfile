FROM python:3.9-buster

RUN python -m pip install --no-cache \
      numpy \
      pycocotools && \
    wget https://github.com/mlcommons/inference/archive/refs/heads/r0.5.zip && \
    unzip r0.5.zip && rm r0.5.zip

