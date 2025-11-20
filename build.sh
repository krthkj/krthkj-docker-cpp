#!/bin/bash

# docker build -t tag:ver -f Dockerfile .
# docker run --rm -it --gpus all tag:ver

# Export the variable, creating a unique timestamp
export BUILD_VERSION=$(date +%Y%m%d-%H%M)

## Build images 
cd amd64
docker compose build
cd ..
sleep 2s

## Push images to docker hub
docker images | grep krthkj/cpp | awk '{print $1":"$2}' | xargs -I {} docker push {}
echo -e "\033[32mPushed docker images to dockerhub\033[0m"
sleep 2s

## remove the docker hub tags after pushing
docker images | grep krthkj/cpp | awk '{print $1":"$2}' | xargs -I {} docker rmi {}
echo -e "\033[32muntagged docker images that were pushed to dockerhub\033[0m"

sleep 2s
echo -e "\033[34mImages with timestamp as tags\033[0m"
docker images | awk '$2 ~ /^[0-9]{8}-[0-9]{4}$/ {print $1":"$2}'