#!/bin/bash

# This scripts requires
#   AURORA_PE_FRAMEWORKS_SRC_DIR
#   AURORA_PE_FRAMEWORKS_INSTALL_DIR
#   ONEAPI_INSTALL_DIR

set -o errexit
#set -o nounset
set -o pipefail

# location of inputs
[[ -z "${AURORA_PE_FRAMEWORKS_SRC_DIR:-}" ]] && AURORA_PE_FRAMEWORKS_SRC_DIR=/input/frameworks/${AURORA_PE_VERSION}
[[ -z "${AURORA_PE_FRAMEWORKS_INSTALL_DIR:-}" ]] && AURORA_PE_FRAMEWORKS_INSTALL_DIR=/opt/aurora/${AURORA_PE_VERSION}/frameworks

#BUILD_ROOT=/home/rramer/dl_fw_conda_env_bkm/2024.1
YAML_FILES_LOC="${AURORA_PE_FRAMEWORKS_SRC_DIR}/yaml_files"
PATCHES_LOC="${AURORA_PE_FRAMEWORKS_SRC_DIR}/patches"
SRC_WHEEL_LOC="${AURORA_PE_FRAMEWORKS_SRC_DIR}/wheels"

TMP_WORK="/tmp/frameworks_install-$(id -un)"
WHEEL_LOC="$TMP_WORK/wheel_files"

# location of conda environment
AURORA_PE_FRAMEWORKS_ENV_NAME="${AURORA_PE_FRAMEWORKS_ENV_NAME:-aurora_nre_models_frameworks-2025.0.1}"
CONDA_ENV_NAME="${AURORA_PE_FRAMEWORKS_ENV_NAME:-aurora_nre_models_frameworks-2025.0.1}"
AURORA_PE_FRAMEWORKS_ENV_MANIFEST="${AURORA_PE_FRAMEWORKS_INSTALL_DIR}/manifests"

# We definitely do not want this.  See config/intel for examples of how to set proxies
# # need access to public resources
# export HTTP_PROXY=http://proxy.alcf.anl.gov:3128
# export HTTPS_PROXY=http://proxy.alcf.anl.gov:3128
# export http_proxy=http://proxy.alcf.anl.gov:3128
# export https_proxy=http://proxy.alcf.anl.gov:3128
# git config --global http.proxy http://proxy.alcf.anl.gov:3128

# modulefile which sets location of IDPROOT

module use "${ONEAPI_MODULE_DIR}"
module use "${INTEL_GPU_UMD_INSTALL_DIR}/modulefiles"
module use "${AURORA_PE_SUPPORT}/modulefiles"
module load oneapi/${DEFAULT_ONEAPI_VERSION}
module load mpich/${DEFAULT_MPICH_MODULE_VERSION}
module load pti-gpu

module -t list

# activate base conda environment
# shellcheck disable=SC1090
source "${IDPROOT}/bin/activate"

#Subdue WARNING: Running pip as the 'root' user can result in broken permissions
export PIP_ROOT_USER_ACTION=ignore

