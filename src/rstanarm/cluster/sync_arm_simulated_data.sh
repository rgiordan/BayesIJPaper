#!/bin/bash
# https://www.digitalocean.com/community/tutorials/how-to-use-rsync-to-sync-local-and-remote-directories-on-a-vps
# https://unix.stackexchange.com/questions/2161/rsync-filter-copying-one-pattern-only
# Note that if you want to include a file, you must also include its parent directory.

REMOTE="REMOTE_USER@REMOTE_HOST:REMOTE_DIR"

rsync -rmv -v $REMOTE \
--include='*SIMULATED_IJ.data.R' \
--include='**/' \
--exclude='*'

