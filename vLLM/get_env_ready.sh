#!/bin/bash
#
#
module restore
module unload mpich oneapi
module use /soft/compilers/oneapi/2025.1.1/modulefiles
module use /soft/compilers/oneapi/nope/modulefiles
module add mpich/nope/develop-git.6037a7a
module add oneapi/public/2025.1.1

source /opt/aurora/24.347.0/spack/unified/0.9.2/install/linux-sles15-x86_64/gcc-13.3.0/miniforge3-24.3.0-0-gfganax/bin/activate
conda activate /lus/flare/projects/Aurora_deployment/datascience/software/envs/conda_envs/vLLM_pytorch_2p8_oneapi_2025p1p1_pti_0p11p0_python3p10p14

WHEEL_LOC=/lus/flare/projects/Aurora_deployment/datascience/software/envs/wheel_factory/vLLM_XCCL_Ratnam/vLLM_pytorch_2p8_oneapi_2025p1p1_pti_0p11p0_python3p10p14
pip install --no-cache-dir --no-deps --force-reinstall ${WHEEL_LOC}/vllm-*.whl
pip uninstall triton -y
pip uninstall pytorch-triton-xpu -y
# pytorch_triton_xpu-3.3.0+git0bcc8265-cp310-cp310-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl
#pip3 install pytorch-triton-xpu==3.3.0+git0bcc8265 --index-url https://download.pytorch.org/whl/nightly/pytorch-triton-xpu/
pip install https://download.pytorch.org/whl/nightly/pytorch_triton_xpu-3.3.0%2Bgit0bcc8265-cp310-cp310-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl

pip uninstall -y tcmlib intel-pti intel-cmplr-lic-rt intel-cmplr-lib-rt impi-rt umf tbb intel-opencl-rt \
    intel-cmplr-lib-ur intel-sycl-rt intel-openmp oneccl mkl dpcpp-cpp-rt onemkl-sycl-rng onemkl-sycl-dft \
    onemkl-sycl-blas oneccl-devel onemkl-sycl-sparse onemkl-sycl-lapack triton
export XPU_CCL_BACKEND="xccl"
