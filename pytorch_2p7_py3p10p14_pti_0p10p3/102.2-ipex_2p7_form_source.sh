#!/bin/bash
#
# Time Stamp
tstamp() {
     date +"%Y-%m-%d-%H%M%S"
}

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

TMP_WORK=/lus/flare/projects/Aurora_deployment/datascience/software/envs/wheel_factory/ipex_2p7
conda activate /lus/flare/projects/Aurora_deployment/datascience/software/envs/conda_envs/pt2p7_py3p10p14_pti0p10p3

echo "Activated the conda environment in $(which conda)"

## Building IPEX wheels requires an installed PyTorch
## Install the PyTorch-2.7 wheel
# temporarily install RC wheels
#LOCAL_WHEEL_LOC=/lus/flare/projects/Aurora_deployment/datascience/software/envs/wheel_factory/pytorch_2p7/pt2p7_py3p10p14_pti0p10p3
#pip install --no-cache-dir -r ${LOCAL_WHEEL_LOC}/pytorch_2p7_requirements_modified.txt
#pip install --no-deps --no-cache-dir --force-reinstall $LOCAL_WHEEL_LOC/torch-*.whl


## FIX ME!!!
# This is much nicer, but we will fix it later!!!
#conda activate $CONDA_ENV_INSTALL_DIR/$CONDA_ENV_NAME

#mkdir -p $TMP_WORK
cd $TMP_WORK
WHEEL_TAG=pt2p7_py3p10p14_pti0p10p3
mkdir -p ${WHEEL_TAG}

# build the IPEX 2.7 wheel
#git clone git@github.com:intel/intel-extension-for-pytorch.git
cd intel-extension-for-pytorch/
#git checkout release/xpu/2.7.10
#git submodule sync && git submodule update --init --recursive

export DPCPP_ROOT=$(realpath $(dirname $(which icpx))/..)
export _GLIBCXX_USE_CXX11_ABI=1 

export CXX=$(which g++)
echo "g++ = $CXX"
export CC=$(which gcc)
echo "CC = $CC"

export REL_WITH_DEB_INFO=1
export BUILD_WITH_CPU=ON

# now the conda env doesn't have MKL in case we want to use different version of MKL from module
# use MKLROOT from module environment
export BUILD_DOUBLE_KERNEL=ON
export MKL_DPCPP_ROOT=${MKLROOT}
export USE_ITT_ANNOTATION=ON
export TORCH_DEVICE_BACKEND_AUTOLOAD=0
export USE_AOT_DEVLIST='pvc'
export TORCH_XPU_ARCH_LIST='pvc'

#export USE_ONEMKL=1
#export TORCH_VERSION="2.7.1"
#export IPEX_VERSION="2.7.10+xpu"
#export IPEX_VERSIONED_BUILD=1

pip uninstall -y mkl mkl-include
python setup.py clean
python setup.py bdist_wheel --verbose --dist-dir ${TMP_WORK}/${WHEEL_TAG} 2>&1 | tee ${TMP_WORK}/${WHEEL_TAG}/"ipex-build-whl-$(tstamp).log"

echo ""
echo "Completed build IPEX wheel"
echo ""

