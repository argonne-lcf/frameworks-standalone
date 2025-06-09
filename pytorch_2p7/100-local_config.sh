#!/bin/bash

# This scripts requires
#   AURORA_PE_FRAMEWORKS_SRC_DIR
#   AURORA_PE_FRAMEWORKS_INSTALL_DIR
#   ONEAPI_INSTALL_DIR

set -o errexit
#set -o nounset
set -o pipefail

# The directory where this repository is cloned
# AURORA_PE_FRAMEWORKS_SRC_DIR equivalent
REPO_SRC_DIR=/lus/flare/projects/Aurora_deployment/datascience/software/frameworks-standalone/pytorch_2p7

# This is where we want the conda environment to be
# AURORA_PE_FRAMEWORKS_INSTALL_DIR equivalent
CONDA_ENV_INSTALL_DIR=/lus/flare/projects/Aurora_deployment/datascience/software/envs/conda_envs/

# location of inputs
[[ -z "${REPO_SRC_DIR:-}" ]] && REPO_SRC_DIR=/frameworks-standalone/pytorch_2p7
[[ -z "${CONDA_ENV_INSTALL_DIR:-}" ]] && CONDA_ENV_INSTALL_DIR=/lus/flare/projects/Aurora_deployment/datascience/software/envs/conda_envs/

#BUILD_ROOT=/home/rramer/dl_fw_conda_env_bkm/2024.1
YAML_FILES_LOC="${REPO_SRC_DIR}/yaml_files"
PATCHES_LOC="${REPO_SRC_DIR}/patches"
SRC_WHEEL_LOC="${REPO_SRC_DIR}/wheels"

TMP_WORK="/tmp/frameworks_install-$(id -un)"
WHEEL_LOC="$TMP_WORK/wheel_files"

#echo "$YAML_FILES_LOC" 

# location of conda environment
#AURORA_PE_FRAMEWORKS_ENV_NAME="${AURORA_PE_FRAMEWORKS_ENV_NAME:-aurora_nre_models_frameworks-2025.0.1}"
CONDA_ENV_NAME="${CONDA_ENV_NAME:-pt2.7_oneapi2025.1.3}"
CONDA_ENV_MANIFEST="${CONDA_ENV_INSTALL_DIR}/manifests"

# We definitely do not want this.  See config/intel for examples of how to set proxies
# # need access to public resources
export HTTP_PROXY=http://proxy.alcf.anl.gov:3128
export HTTPS_PROXY=http://proxy.alcf.anl.gov:3128
export http_proxy=http://proxy.alcf.anl.gov:3128
export https_proxy=http://proxy.alcf.anl.gov:3128
# git config --global http.proxy http://proxy.alcf.anl.gov:3128

# modulefile which sets location of IDPROOT

module restore
module unload oneapi
module use /soft/compilers/oneapi/2025.1.3/modulefiles
module use /soft/compilers/oneapi/nope/modulefiles
module add mpich/nope/develop-git.6037a7a
export A21_SDK_PTIROOT_OVERRIDE=/opt/aurora/24.347.0/oneapi/pti/latest ## 0.11.0
module add oneapi/public/2025.1.3
echo "PTI-GPU root after oneapi/2025.1.3: $PTIROOT"
#export PTIROOT=/opt/aurora/24.347.0/oneapi/pti/latest
#module load cmake/3.25.3

module -t list

echo "PTI-GPU Root: $PTIROOT"

# activate base conda environment
# shellcheck disable=SC1090
#source "${IDPROOT}/bin/activate"
#
# In our current setup which is the early testing phase of 25.070.0/frameworks
# We get a conda the following way

module load miniforge3/24.3.0-0
source /opt/aurora/24.347.0/spack/unified/0.9.2/install/linux-sles15-x86_64/gcc-13.3.0/miniforge3-24.3.0-0-gfganax/bin/activate

echo "Activated the base conda environment"
echo "The Base conda is coming from $(which conda)"

#Subdue WARNING: Running pip as the 'root' user can result in broken permissions
export PIP_ROOT_USER_ACTION=ignore

