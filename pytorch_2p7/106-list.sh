#!/bin/bash

source "100-local_config.sh"

conda activate $CONDA_ENV_INSTALL_DIR/$CONDA_ENV_NAME

mkdir -p  $CONDA_ENV_MANIFEST

conda list > $CONDA_ENV_MANIFEST/${CONDA_ENV_NAME}_conda_env.list 2>&1

pip list > $CONDA_ENV_MANIFEST/${CONDA_ENV_NAME}_pip.list 2>&1

conda deactivate

echo "Completed creating PyTorch 2.7 conda environment"


