#!/bin/bash
set -e

cd $1

#source /flare/Aurora_deployment/intel/pytorch/envs/build_pt2.8_oneapi2025.1.3.env
source /flare/Aurora_deployment/intel/pytorch/envs/build_pt2.7_oneapi2025.1.3.env

export DPCPP_ROOT=$(realpath $(dirname $(which icpx))/..)
export CXX=$(which g++)
export CC=$(which gcc)

export BUILD_DOUBLE_KERNEL=ON
export MKL_DPCPP_ROOT=${MKLROOT}
export USE_ITT_ANNOTATION=ON
export BUILD_WITH_CPU=ON
export _GLIBCXX_USE_CXX11_ABI=1
export TORCH_DEVICE_BACKEND_AUTOLOAD=0
export USE_AOT_DEVLIST="pvc"
export TORCH_XPU_ARCH_LIST="pvc"

#pip uninstall -y mkl mkl-include
python setup.py clean
MAX_JOBS=32 python setup.py bdist_wheel
