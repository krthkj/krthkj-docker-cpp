#!/bin/bash

# Removed dangling images only
docker image prune -f

# removes all unused images including dangiling and images not refecenced by any container
#docker image prune -a -f

# Removed all unused images created more than 7 days ago nad dangling images
docker image prune -a --filter "until=168h" -f

## Removes all stopped containers, all networks not used by at least one container, all dangling images,
## and all unused images (not just dangling ones). 
## WARNING: This removes all images not currently associated with a container. If you have older versions
##          you want to keep as a backup, use the next command instead
# docker system prune -a -f

## Performs the cleanup above AND removes all unused volumes.
## WARNING: Volumes contain data! Use this command only if you are certain the data in unused volumes is not needed.
#docker system prune -a --volumes -f
