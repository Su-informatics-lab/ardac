#!/bin/bash
set -e

export SQLALCHEMY_SILENCE_UBER_WARNING=1

# Activate the virtual environment
source /app/venvs/dict/bin/activate

#which python
#which poetry

#ls /app/venvs/dict/lib/python3.10/site-packages/*dictionary*
#ls /app/venvs/dict/lib/python3.10/site-packages/*gdc*
#ls /app/venvs/dict/lib/python3.10/site-packages/*dictionaryutils*

# Define the host directory to mount
HOST_DIR="/mnt/host"

# Copy YAML files from the host directory to the container's schema directory
SCHEMA_DIR=$(python -c "from gdcdictionary import SCHEMA_DIR; print(SCHEMA_DIR)")
#echo $SCHEMA_DIR

#ls $HOST_DIR/gdcdictionary/schemas/*.yaml

# Copy YAML files from the host directory to the container's schema directory
cp $HOST_DIR/gdcdictionary/schemas/*.yaml $SCHEMA_DIR

pytest tests -s -v

# change dir to produce dictionary json
cd $HOST_DIR
python /app/bin/dump_schema.py

set +e
