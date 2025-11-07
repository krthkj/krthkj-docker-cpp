#!/bin/bash

# docker build -t tag:ver -f Dockerfile .
# docker run --rm -it --gpus all tag:ver

cd amd64
docker compose build
cd ..
