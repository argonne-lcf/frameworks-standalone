#!/bin/bash

source "100-local_config.sh"

# create conda env
#conda create -p $AURORA_PE_FRAMEWORKS_INSTALL_DIR/$AURORA_PE_FRAMEWORKS_ENV_NAME --clone ${AURORA_BASE_ENV}
ENVPREFIX=$CONDA_ENV_INSTALL_DIR/$CONDA_ENV_NAME
rm -rf ${ENVPREFIX} 
mkdir -p ${ENVPREFIX}
# FULL PATH
export ENVFULLPATH=$(realpath ${ENVPREFIX})
echo ENVFULLPATH:$ENVFULLPATH
#rm -rf ${ENVPREFIX}  

# Will install Python IDP
export CONDA_PKGS_DIRS=${ENVPREFIX}/../.conda/pkgs
export PIP_CACHE_DIR=${ENVPREFIX}/../.pip
conda create python=3.11.11 --prefix ${ENVPREFIX} --override-channels \
           --channel https://software.repos.intel.com/python/conda/linux-64 \
           --channel conda-forge \
           --insecure \
           --strict-channel-priority \
           --yes

conda activate ${ENVPREFIX}

# Will install Python from conda-forge for some reason?
conda env update --prefix ${ENVPREFIX} --file  $YAML_FILES_LOC/conda_intel_python.yml --prune

# Remove Python and numpy from conda
conda remove python --prefix ${ENVPREFIX} \
        --override-channels \
        --channel https://software.repos.intel.com/python/conda \
        --channel conda-forge \
        --insecure \
        --force \
        --yes

# Reinstall Python to get Intel IDP
conda install python=3.11.11 --prefix ${ENVPREFIX} \
        --override-channels \
        --channel https://software.repos.intel.com/python/conda/linux-64 \
        --channel conda-forge \
        --insecure \
        --strict-channel-priority \
        --yes

# Set +e to remove error if package is not already installed.  We want to continue
# and not abort the rest of the installation script
set +e
#rm_conda_pkgs=("impi_rt" "intel-opencl-rt" "pyedit" "level-zero" "mkl" "mkl-service" "mkl_fft" "mkl_random" "mkl_umath" "intel-cmplr-lib-rt" "intel-cmplr-lib-ur" "intel-sycl-rt" "tcm" "umf" "numpy" "numpy-base")
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
#set -e


pip install numpy==1.26.4


FORTRAN_LIBS="libifport.so* libifcoremt.so*"
mkdir -p ${ENVPREFIX}/lib/libifport
cd ${ENVPREFIX}/lib
cp ${FORTRAN_LIBS} libifport

echo ""
echo "Completed NRE model dependency update"
echo ""


