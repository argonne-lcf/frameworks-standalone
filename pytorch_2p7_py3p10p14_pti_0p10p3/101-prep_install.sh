#!/bin/bash

source "100-local_config.sh"

#Prevent error on RO FS
#OSError: [Errno 30] Read-only file system: '/input/frameworks/23.275.1/2023.2-yaml_files/condaenv.uxpgh7__.requirements.txt'
#rm -rf "${TMP_WORK}"
#mkdir -p "${WHEEL_LOC}"
#rsync -aHS ${SRC_WHEEL_LOC}/ ${WHEEL_LOC}/

#rm -rf "${CONDA_ENV_INSTALL_DIR}"
#mkdir -p "${CONDA_ENV_INSTALL_DIR}"
mkdir -p "${CONDA_ENV_MANIFEST}"

echo "Remove any conda environment with same name"
conda env remove -p ${CONDA_ENV_INSTALL_DIR}/${CONDA_ENV_NAME} || true

echo ""
echo "Completed setup, ready to create conda environment"
echo ""

