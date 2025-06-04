#!/bin/bash

source "800-local_config.sh"

conda activate $AURORA_PE_FRAMEWORKS_INSTALL_DIR/$AURORA_PE_FRAMEWORKS_ENV_NAME

mkdir -p  $AURORA_PE_FRAMEWORKS_ENV_MANIFEST

conda list > $AURORA_PE_FRAMEWORKS_ENV_MANIFEST/nre_models_conda_env.list 2>&1

pip list > $AURORA_PE_FRAMEWORKS_ENV_MANIFEST/nre_models_pip.list 2>&1

conda deactivate

echo "Completed creating 2024.2.1 DL FW NRE model conda environment"


