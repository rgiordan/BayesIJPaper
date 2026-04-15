#!/bin/bash
# https://www.digitalocean.com/community/tutorials/how-to-use-rsync-to-sync-local-and-remote-directories-on-a-vps
# https://unix.stackexchange.com/questions/2161/rsync-filter-copying-one-pattern-only
# Note that if you want to include a file, you must also include its parent directory.

SERVER=snape
MODEL_TYPE="reg_misspecified"



REMOTE_GIT="REMOTE_USER@REMOTE_HOST:REMOTE_DIRECTORY"
LOCAL_GIT=$(git rev-parse --show-toplevel)

rsync -rmv -v ${REMOTE_GIT}"/bayes/output/simulations*"${MODEL_TYPE}* \
${LOCAL_GIT}/src/bayes/output/ \
--include='output' \
--include='*.Rdata' \
--exclude='*' \
--exclude='**/*'

