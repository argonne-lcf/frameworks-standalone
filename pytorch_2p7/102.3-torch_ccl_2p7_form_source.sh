#!/bin/bash

source "100-local_config.sh"

# Suggestion from Sean. Don't want to use "cmake" from conda
module load cmake
unset CMAKE_ROOT

# Commenting out explicit manual path updating. "module load gcc/13.3.0" puts
# all the paths correctly. Checked from a compute node maually
#
#export CPATH="/opt/aurora/24.347.0/spack/unified/0.9.2/install/linux-sles15-x86_64/gcc-13.3.0/gcc-13.3.0-4enwbrb/include":$CPATH
#export LD_LIBRARY_PATH="/opt/aurora/24.347.0/spack/unified/0.9.2/install/linux-sles15-x86_64/gcc-13.3.0/gcc-13.3.0-4enwbrb/lib64":$LD_LIBRARY_PATH
#export PATH="/opt/aurora/24.347.0/spack/unified/0.9.2/install/linux-sles15-x86_64/gcc-13.3.0/gcc-13.3.0-4enwbrb/bin":$PATH

TMP_WORK=/lus/flare/projects/Aurora_deployment/datascience/software/envs/wheel_factory/torch_ccl_2p7
# It seems torch_ccl requires an IPEX installation for it to build the XPU .so
# files. The environment below has a pip installed version of IPEX-2.7.0
# from the publicly available wheel, which was probably built with 
# oneapi/2025.0.x
conda activate /lus/flare/projects/datasets/softwares/envs/env_pip_pytorch_2p7

echo "Activated the conda environment in $(which conda)"

## Building IPEX wheels requires an installed PyTorch
## Install the PyTorch-2.7 wheel
# temporarily install RC wheels
#LOCAL_WHEEL_LOC=/lus/flare/projects/Aurora_deployment/datascience/software/envs/wheel_factory/pytorch_2p7
#pip install --force-reinstall $LOCAL_WHEEL_LOC/torch-*.whl


## FIX ME!!!
# This is much nicer, but we will fix it later!!!
#conda activate $CONDA_ENV_INSTALL_DIR/$CONDA_ENV_NAME

#mkdir -p $TMP_WORK
cd $TMP_WORK

# build the torch_ccl 2.7 wheel
#git clone git@github.com:intel/torch-ccl.git
cd torch-ccl/
#git checkout origin/ccl_torch2.7.0+xpu
#git submodule sync && git submodule update --init --recursive
#
#export LD_LIBRARY_PATH="/usr/lib64:$LD_LIBRARY_PATH"
#
export CPATH=$CONDA_PREFIX/include:$CPATH 

#export CMAKE_PREFIX_PATH="${CONDA_PREFIX:-'$(dirname $(which conda))/../'}:${CMAKE_PREFIX_PATH}"
#export CMAKE_PREFIX_PATH="/opt/aurora/24.347.0/spack/unified/0.9.2/install/linux-sles15-x86_64/gcc-13.3.0/gcc-13.3.0-4enwbrb/."
export DPCPP_ROOT=$(realpath $(dirname $(which icpx))/..)
export COMPUTE_BACKEND=dpcpp
export _GLIBCXX_USE_CXX11_ABI=1 

export CXX=$(which g++)
echo "g++ = $CXX"
export CC=$(which gcc)
echo "CC = $CC"

export CC_FOR_BUILD=$(which gcc)
export CXX_FOR_BUILD=$(which g++)

export CMAKE_CXX_FLAGS="-Wno-error -Wno-terminate -Wno-deprecated-attributes -Wno-unused-but-set-variable"
export CMAKE_C_FLAGS="-Wno-error"

export REL_WITH_DEB_INFO=1

export USE_SYSTEM_ONECCL=ON
export TORCH_DEVICE_BACKEND_AUTOLOAD=0

python setup.py clean
MAX_JOBS=48 python setup.py bdist_wheel --verbose --dist-dir ${TMP_WORK}

echo ""
echo "Completed build oneccl_bindings_for_pytorch wheel"
echo ""

