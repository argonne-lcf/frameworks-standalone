#!/bin/bash

source "100-local_config.sh"

TMP_WORK=/lus/flare/projects/Aurora_deployment/datascience/software/envs/wheel_factory/pytorch_2p7
conda activate /lus/flare/projects/Aurora_deployment/datascience/software/envs/conda_envs/conda_python_3.11

## FIX ME!!!
# This is much nicer, but we will fix it later!!!
#conda activate $CONDA_ENV_INSTALL_DIR/$CONDA_ENV_NAME

#mkdir -p $TMP_WORK
cd $TMP_WORK

# build the pytorch 2.7 wheel
#git clone https://github.com/pytorch/pytorch.git
cd pytorch
#git checkout release/2.7
#git submodule sync && git submodule update --init --recursive
#
export LD_LIBRARY_PATH="/usr/lib64:$LD_LIBRARY_PATH"

export CMAKE_PREFIX_PATH="${CONDA_PREFIX:-'$(dirname $(which conda))/../'}:${CMAKE_PREFIX_PATH}"
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
export USE_CUDA=0
export USE_ROCM=0
export USE_MKLDNN=1
#export USE_BLAS=mkl
export USE_MKL=1
export USE_ROCM=0
export USE_CUDNN=0
export USE_FBGEMM=0
export USE_NNPACK=0
export USE_QNNPACK=0
export USE_NCCL=0
export USE_CUDA=0
export BUILD_CAFFE2_OPS=0
export BUILD_TEST=0
export USE_DISTRIBUTED=1
export USE_NUMA=0
export USE_MPI=0
export _GLIBCXX_USE_CXX11_ABI=1
export USE_XPU=1
export USE_XCCL=1
export XPU_ENABLE_KINETO=1
export USE_ONEMKL=1
export USE_KINETO=1

export USE_AOT_DEVLIST='pvc'
export TORCH_XPU_ARCH_LIST='pvc'

## These does not overwrite the defaults in .ci/docker/triton_version.txt!!!
#export TRITON_VERSION='3.3.0'
#export TRITON_XPU_COMMIT_ID='83111ab2'

#export TRITON_VERSION='3.3.1'
#export TRITON_XPU_COMMIT_ID='b0e26b73'

#export TRITON_VERSION='3.3.1'
#export TRITON_XPU_COMMIT_ID='b0e26b73'


#3.3.1+gitb0e26b73

# now the conda env doesn't have MKL in case we want to use different version of MKL from module
# use MKLROOT from module environment
export INTEL_MKL_DIR=$MKLROOT

#pip install --no-cache-dir -r requirements.txt
pip install -r requirements.txt


python setup.py clean
make triton
MAX_JOBS=32 python setup.py bdist_wheel --dist-dir ${TMP_WORK}

echo ""
echo "Completed build pytorch wheel"
echo ""

