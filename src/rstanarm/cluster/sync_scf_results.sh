#!/bin/bash
# https://www.digitalocean.com/community/tutorials/how-to-use-rsync-to-sync-local-and-remote-directories-on-a-vps
# https://unix.stackexchange.com/questions/2161/rsync-filter-copying-one-pattern-only
# Note that if you want to include a file, you must also include its parent directory.

SERVER=gandalf

REMOTE_GIT=/accounts/grad/rgiordano/Documents/git_repos/InfinitesimalJackknifeWorkbench
LOCAL_GIT=/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench

# Peace password
rsync -rmv -v \
rgiordano@${SERVER}.berkeley.edu:\
$REMOTE_GIT/src/bayes/rstanarm/cluster/output/* \
$LOCAL_GIT/src/bayes/rstanarm/cluster/output/ \
--include='output' \
--include='*.Rdata' \
--exclude='*' \
--exclude='**/*'




#--include='output' \
# /accounts/grad/rgiordano/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes/example-models/example-models \

# --dry-run --verbose
