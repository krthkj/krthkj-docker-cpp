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

## display all images with timestamp tags
echo -e "\033[34mImages with timestamp as tags\033[0m"
docker images | awk '$2 ~ /^[0-9]{8}-[0-9]{4}$/ {print $1":"$2}'
sleep 2s

## Delete all images with timestamp tags older than 1 day
TIME_1_DAY_AGO=$(date +%s -d "1 day ago")
echo -e "\033[34mFinding ALL timestamp tags created OLDER than 1 day ago...\033[0m"
docker images --format '{{.Repository}}:{{.Tag}} {{.CreatedAt}}' | \
awk -v T_CUTOFF="${TIME_1_DAY_AGO}" '
{
    IMAGE_TAG = $1
    TAG = $1
    # Remove the repository part to isolate the tag for checking
    sub(/.*:/, "", TAG)
    
    CREATED_AT_SEC = $2
    
    # 1. Check if the tag is a timestamp (YYYYMMDD-HHMM)
    if (TAG ~ /^[0-9]{8}-[0-9]{4}$/) {
        # 2. Check if the creation time is LESS THAN the cutoff time (meaning it is OLDER than 1 day ago)
        if (CREATED_AT_SEC < T_CUTOFF) {
            print IMAGE_TAG
        }
    }
}' | xargs -r docker rmi 

if [ $? -eq 0 ]; then
    echo -e "\n\033[32mSuccessfully deleted timestamp tags older than 1 day for ALL repos.\033[0m"
else
    echo -e "\n\033[31mError during tag deletion or no matching tags found.\033[0m"
fi
docker image prune -a --filter "until=24h" -f