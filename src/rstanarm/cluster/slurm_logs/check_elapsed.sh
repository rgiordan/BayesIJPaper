#!/bin/bash
for x in `ls -t | head -n 12`; do cat $x | grep Elapsed | wc -l; done
