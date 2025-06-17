#!/bin/bash -x
#
# Time Stamp
tstamp() {
     date +"%Y-%m-%d-%H%M%S"
}
## Proxies to clone from a compute node
export HTTP_PROXY=http://proxy.alcf.anl.gov:3128
export HTTPS_PROXY=http://proxy.alcf.anl.gov:3128
export http_proxy=http://proxy.alcf.anl.gov:3128
#
CONDA_ENV_INSTALL_DIR=/lus/flare/projects/Aurora_deployment/datascience/software/envs/conda_envs
CONDA_ENV_NAME=pytorch_2p7_oneapi_2025p1p3_pti_0p11p0_python3p10p14_julia

source /opt/aurora/24.347.0/spack/unified/0.9.2/install/linux-sles15-x86_64/gcc-13.3.0/miniforge3-24.3.0-0-gfganax/bin/activate
ENVPREFIX=$CONDA_ENV_INSTALL_DIR/$CONDA_ENV_NAME
rm -rf ${ENVPREFIX}
mkdir -p ${ENVPREFIX}

export CONDA_PKGS_DIRS=${ENVPREFIX}/../.conda/pkgs
export PIP_CACHE_DIR=${ENVPREFIX}/../.pip

echo "Creating Conda environment with Python 3.10.14"
conda create python=3.10.14 --prefix ${ENVPREFIX} --override-channels \
           --channel https://software.repos.intel.com/python/conda/linux-64 \
           --channel conda-forge \
           --insecure \
           --strict-channel-priority \
           --yes

conda activate ${ENVPREFIX}
echo "Conda is coming from $(which conda)"

# Load modules 2025.1.3 with PTI 0.10
module restore
module unload oneapi mpich
module use /soft/compilers/oneapi/2025.1.3/modulefiles
module use /soft/compilers/oneapi/nope/modulefiles
module add mpich/nope/develop-git.6037a7a
A21_SDK_PTIROOT_OVERRIDE=/opt/aurora/24.347.0/oneapi/pti/latest module add oneapi/public/2025.1.3

export CXX=$(which g++)
export CC=$(which gcc)

export REL_WITH_DEB_INFO=1
export USE_CUDA=0
export USE_ROCM=0
export USE_MKLDNN=1
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

export INTEL_MKL_DIR=$MKLROOT

TMP_WORK=/lus/flare/projects/Aurora_deployment/datascience/software/envs/wheel_factory/pytorch_2p7
cd $TMP_WORK

mkdir -p ${CONDA_ENV_NAME}

#git clone https://github.com/pytorch/pytorch.git
cd pytorch
#git checkout release/2.7
#git submodule sync && git submodule update --init --recursive

pip install --no-cache-dir -r requirements.txt

python setup.py clean
pip install --no-cache-dir pytorch-triton-xpu==3.3.1+gitb0e26b73 --index-url https://download.pytorch.org/whl/nightly/
MAX_JOBS=32 python setup.py bdist_wheel --dist-dir ${TMP_WORK}/${CONDA_ENV_NAME} 2>&1 | tee ${TMP_WORK}/${CONDA_ENV_NAME}/"torch-build-whl-$(tstamp).log"
