#!/bin/bash

source /app/venvs/dict/bin/activate

# Install Poetry
pip install poetry

# need to apply setuptools update after poetry install
pip install setuptools -U

# Install dependencies using Poetry
poetry install -v

# Install pytest
pip install pytest -U

pip install deepdiff -U
