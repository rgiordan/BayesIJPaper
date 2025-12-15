#!/bin/bash

TARGET_DIR="/accounts/fac/rgiordano/Documents/git_repos/InfinitesimalJackknifeWorkbench/src/bayes/mrp/bootstrap_data/"



#scp rgiordano@shelob.berkeley.edu:$TARGET_DIR/mrp_combined_mrp_20240724_1324.Rdata .
#scp rgiordano@shelob.berkeley.edu:$TARGET_DIR/mrp_original_seed134432_samples5000_mrp_postprocessed.Rdata .
#scp rgiordano@shelob.berkeley.edu:$TARGET_DIR/mrp_originallmer_seed134432_samples5000.Rdata .
scp rgiordano@shelob.berkeley.edu:$TARGET_DIR/mrp_bootstrap_seed1_samples5000.Rdata .
