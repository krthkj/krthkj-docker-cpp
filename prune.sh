#!/bin/bash

# Removed dangling images only
docker image prune -f

# removes all unused images including dangiling and images not refecenced by any container
# docker image prune -a -f

# Removed all unused images created more than 1 days ago and dangling images
docker image prune -a --filter "until=24h" -f

## Purge all the tags which has timestamp
# docker images --format "{{.Repository}}:{{.Tag}}" | grep -E ":[0-9]{8}-[0-9]{4}$" | xargs -r docker rmi

## Removes all stopped containers, all networks not used by at least one container, all dangling images,
## and all unused images (not just dangling ones). 
## WARNING: This removes all images not currently associated with a container. If you have older versions
##          you want to keep as a backup, use the next command instead
# docker system prune -a -f

## Performs the cleanup above AND removes all unused volumes.
## WARNING: Volumes contain data! Use this command only if you are certain the data in unused volumes is not needed.
#docker system prune -a --volumes -f

# --- CONFIGURATION ---
# Calculate the single cutoff time in seconds since the epoch
# TIME_1_DAY_AGO: Any image created BEFORE this time (i.e., less than this number) is older than 1 day.
TIME_1_DAY_AGO=$(date +%s -d "1 day ago") 
# ---------------------

echo ""
echo -e "\033[34mFinding ALL timestamp tags created OLDER than 1 day ago...\033[0m"
# Find images created older than 1 day and delete the corresponding tags
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
