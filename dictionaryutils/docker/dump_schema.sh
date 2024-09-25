#!/bin/bash

# Activate the virtual environment
source /app/venvs/dict/bin/activate

# Define the host directory to mount
HOST_DIR="/mnt/host"

# change dir to produce dictionary json
cd $HOST_DIR
python /app/bin/dump_schema.py

echo "Dump completed!"
