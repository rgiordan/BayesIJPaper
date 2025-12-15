#!/bin/bash
# https://www.digitalocean.com/community/tutorials/how-to-use-rsync-to-sync-local-and-remote-directories-on-a-vps
# https://unix.stackexchange.com/questions/2161/rsync-filter-copying-one-pattern-only
# Note that if you want to include a file, you must also include its parent directory.

SERVER=snape

# Peace password
rsync -rmv -v \
/home/rgiordan/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes/example-models/ARM/ \
rgiordano@${SERVER}.berkeley.edu:\
/accounts/grad/rgiordano/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes/example-models/ARM/ \
--include='*SIMULATED_IJ.data.R' \
--include='**/' \
--exclude='*'



#--include='output' \
# /accounts/grad/rgiordano/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes/example-models/example-models \

# --dry-run --verbose
