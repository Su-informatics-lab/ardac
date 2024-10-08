#!/bin/bash
set -e

export SQLALCHEMY_SILENCE_UBER_WARNING=1

# Activate the virtual environment
source /app/venvs/dict/bin/activate

# Define the host directory to mount
HOST_DIR="/mnt/host"

# Add global config to avoid fatal security error
git config --global --add safe.directory $HOST_DIR

# Try to get commit and tag information from git
if [[ -d $HOST_DIR/.git && -d $HOST_DIR/gdcdictionary ]]; then
  (
    cd $HOST_DIR
    DICTCOMMIT=`git rev-parse HEAD` && echo "DICTCOMMIT=\"${DICTCOMMIT}\"" >/app/dictionaryutils/version_data.py
    DICTVERSION=`git describe --always --tags` && echo "DICTVERSION=\"${DICTVERSION}\"" >>/app/dictionaryutils/version_data.py
  )
fi

# Copy YAML files from the host directory to the container's schema directory
SCHEMA_DIR=$(python -c "from gdcdictionary import SCHEMA_DIR; print(SCHEMA_DIR)")

# Copy YAML files from the host directory to the container's schema directory
cp $HOST_DIR/gdcdictionary/schemas/*.yaml $SCHEMA_DIR

# Run tests and save output for validation check
pytest tests -s -v --junitxml=$HOST_DIR/results.xml

# change dir to produce dictionary json
cd $HOST_DIR
python /app/bin/dump_schema.py

set +e
