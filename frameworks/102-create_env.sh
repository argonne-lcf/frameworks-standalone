#!/bin/bash

source "800-local_config.sh"

# create conda env
#conda create -p $AURORA_PE_FRAMEWORKS_INSTALL_DIR/$AURORA_PE_FRAMEWORKS_ENV_NAME --clone ${AURORA_BASE_ENV}
ENVPREFIX=$AURORA_PE_FRAMEWORKS_INSTALL_DIR/$AURORA_PE_FRAMEWORKS_ENV_NAME
mkdir -p ${ENVPREFIX}
# FULL PATH
export ENVFULLPATH=$(realpath ${ENVPREFIX})
echo ENVFULLPATH:$ENVFULLPATH
rm -rf ${ENVPREFIX}  

# tweak for larcv3. larcv3 package needs HDF5_ROOT defined
export HDF5_ROOT=${ENVFULLPATH}

# Will install Python IDP
export CONDA_PKGS_DIRS=${ENVPREFIX}/../.conda/pkgs
export PIP_CACHE_DIR=${ENVPREFIX}/../.pip
conda create python=3.10.14 --prefix ${ENVPREFIX} --override-channels \
           --channel https://software.repos.intel.com/python/conda/linux-64 \
           --channel conda-forge \
           --insecure \
           --strict-channel-priority \
           --yes

conda activate ${ENVPREFIX}

# Will install Python from conda-forge for some reason?
conda env update --prefix ${ENVPREFIX} --file  $YAML_FILES_LOC/aurora_nre_model_dependencies.yml --prune

# Remove Python and numpy from conda
conda remove python --prefix ${ENVPREFIX} \
        --override-channels \
        --channel https://software.repos.intel.com/python/conda \
        --channel conda-forge \
        --insecure \
        --force \
        --yes

# Reinstall Python to get Intel IDP
conda install python=3.10.14 --prefix ${ENVPREFIX} \
        --override-channels \
        --channel https://software.repos.intel.com/python/conda/linux-64 \
        --channel conda-forge \
        --insecure \
        --strict-channel-priority \
        --yes

# Set +e to remove error if package is not already installed.  We want to continue
# and not abort the rest of the installation script
set +e
rm_conda_pkgs=("impi_rt" "intel-opencl-rt" "pyedit" "level-zero" "mkl" "mkl-service" "mkl_fft" "mkl_random" "mkl_umath" "intel-cmplr-lib-rt" "intel-cmplr-lib-ur" "intel-sycl-rt" "tcm" "umf" "numpy" "numpy-base")
for pkg in "${rm_conda_pkgs[@]}"
do
    conda uninstall $pkg \
        --prefix ${ENVPREFIX} \
        --force \
        --yes
    pip uninstall $pkg -y
done
set -e


pip install numpy==1.26.4


FORTRAN_LIBS="libifport.so* libifcoremt.so*"
mkdir -p ${ENVPREFIX}/lib/libifport
cd ${ENVPREFIX}/lib
cp ${FORTRAN_LIBS} libifport

echo ""
echo "Completed NRE model dependency update"
echo ""


