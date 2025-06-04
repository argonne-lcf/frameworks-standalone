#!/bin/bash

source "800-local_config.sh"

conda activate $AURORA_PE_FRAMEWORKS_INSTALL_DIR/$AURORA_PE_FRAMEWORKS_ENV_NAME

# TODO: Move to using conda yaml file instead of wheel files once packages are availble publicly
# install frameworks components
PIP_UPGRADE=1 PIP_NO_DEPS=1 PIP_FORCE_REINSTALL=1 conda env update -f $YAML_FILES_LOC/intel_dl_frameworks-2025.0.1.yml

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
pip install mpi4py==3.1.6

echo ""
echo "Completed adjustments for mpich support"
echo ""

# need to add scikit-image and cloud-volume, at some point these
# can be incorporated into the dependencies yaml file
pip install scikit-image

pip install cloud-volume

echo ""
echo "Completed adding dependencies for FFN inference"
echo ""


