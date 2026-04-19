#!/bin/bash

# Copy selected bootstraps to the local directory

LOCAL_BASE_DIR=$(git rev-parse --show-toplevel)
REMOTE_BASE_DIR=SET_REMOTE_DIR
OUTPUT_DIR="src/singular_simulations/output"
HOST=scf3

FILES=super_simple_simulation_sim*_results_redim100_obsperre100_seed100.Rdata

rsync -vai \
    $HOST:$SCF_BASE_DIR/$MODEL_DIR/${OUTPUT_DIR}/${FILES} \
    $REMOTE_BASE_DIR/$MODEL_DIR/${OUTPUT_DIR}/



