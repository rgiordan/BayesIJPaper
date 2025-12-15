#!/bin/bash
# https://www.digitalocean.com/community/tutorials/how-to-use-rsync-to-sync-local-and-remote-directories-on-a-vps
# https://unix.stackexchange.com/questions/2161/rsync-filter-copying-one-pattern-only
# Note that if you want to include a file, you must also include its parent directory.

SERVER=snape
MODEL_TYPE="reg_misspecified"


# Peace password
rsync -rmv -v \
rgiordano@${SERVER}.berkeley.edu:\
/accounts/grad/rgiordano/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes/output/simulations*${MODEL_TYPE}* \
/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes/output/ \
--include='output' \
--include='*.Rdata' \
--exclude='*' \
--exclude='**/*'




#--include='output' \
# /accounts/grad/rgiordano/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes/example-models/example-models \

# --dry-run --verbose
