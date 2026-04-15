#!/bin/bash

TARGET_HOST="REMOTE_USER@REMOTE_HOST:REMOTE_DIRECTORY"


scp $TARGET_HOST/mrp_combined_mrp_20240724_1324.Rdata .
scp $TARGET_HOST/mrp_original_seed134432_samples5000_mrp_postprocessed.Rdata .
scp $TARGET_HOST/mrp_originallmer_seed134432_samples5000.Rdata .
scp $TARGET_HOST/mrp_bootstrap_seed1_samples5000.Rdata .
