#!/bin/bash

# Activate the virtual environment
source /app/venvs/dict/bin/activate

# Define the host directory to mount
HOST_DIR="/mnt/host"

python /app/bin/ardac_dictionary_compare.py -dirpath $HOST_DIR
