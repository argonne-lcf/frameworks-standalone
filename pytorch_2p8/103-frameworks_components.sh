#!/bin/bash

source "100-local_config.sh"

conda activate $CONDA_ENV_INSTALL_DIR/$CONDA_ENV_NAME

# TODO: Move to using conda yaml file instead of wheel files once packages are availble publicly
# install frameworks components
PIP_UPGRADE=1 PIP_NO_DEPS=1 PIP_FORCE_REINSTALL=1 conda env update -f $YAML_FILES_LOC/pytorch_2p7.yml

# temporarily install RC wheels
# LOCAL_WHEEL_LOC=${AURORA_PE_FRAMEWORKS_SRC_DIR}/wheels
# pip install --upgrade --no-deps --force-reinstall $LOCAL_WHEEL_LOC/torch-*.whl
# pip install --upgrade --no-deps --force-reinstall $LOCAL_WHEEL_LOC/intel_extension_for_pytorch-*.whl
# pip install --upgrade --no-deps --force-reinstall $LOCAL_WHEEL_LOC/oneccl_bind_pt-*.whl
# pip install --upgrade --no-deps --force-reinstall $LOCAL_WHEEL_LOC/torchvision-*.whl
# pip install --upgrade --no-deps --force-reinstall $LOCAL_WHEEL_LOC/intel_extension_for_tensorflow-*.whl
# pip install --upgrade --no-deps --force-reinstall $LOCAL_WHEEL_LOC/intel_extension_for_tensorflow_lib-*.whl

echo ""
echo "Completed installing frameworks components"
echo ""

# # remove conflicting conda packages
# PKG_REMOVAL_LIST="impi_rt intel-opencl-rt pyedit level-zero mkl mkl-service mkl_fft mkl_random mkl_umath intel-cmplr-lib-rt intel-sycl-rt"
rm_conda_pkgs=(
        "dpcpp-cpp-rt"
        "impi_rt"
        "intel-cmplr-lib-rt"
        "intel-cmplr-lib-ur"
        "intel-cmplr-lic-rt"
        "intel-gpu-ocl-icd-system"
        "intel-opencl-rt"
        "intel-openmp"
        "intelpython"
        "intel-sycl-rt"
        "level-zero"
        "libedit"
        "mkl"
        "mkl_fft"
        "mkl_random"
        "mkl-service"
        "mkl_umath"
        "numpy"
        "numpy-base"
        "onemkl-sycl-blas"
        "onemkl-sycl-dft"
        "onemkl-sycl-lapack"
        "onemkl-sycl-rng"
        "onemkl-sycl-stats"
        "onemkl-sycl-vm"
        "pyedit"
        "tbb"
        "tcm"
        "umf"
    )
for pkg in "${rm_conda_pkgs[@]}"
do
    conda uninstall $pkg \
        --prefix ${ENVPREFIX} \
        --force \
        --yes
    pip uninstall $pkg -y
done
set -e

# for pkg in $PKG_REMOVAL_LIST
# do
#         echo "checking for $pkg"
#         if (( $(conda list | grep -c $pkg) > 0 )); then
#             echo "Removing $pkg package from conda environment"
#             conda remove --force -y $pkg
#     fi
# done

# echo ""
# echo "Completing removing conflicting packages"
# echo ""

# no longer installed in IDP base environment, install after impi_rt is removed
pip install mpi4py==4.0.3

echo ""
echo "Completed adjustments for mpich support"
echo ""


