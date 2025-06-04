#!/bin/bash

source "800-local_config.sh"

conda activate $AURORA_PE_FRAMEWORKS_INSTALL_DIR/$AURORA_PE_FRAMEWORKS_ENV_NAME

mkdir -p $TMP_WORK
cd $TMP_WORK

# build and install horovod wheel
rm -rf intel-optimization-for-horovod
git clone https://github.com/intel/intel-optimization-for-horovod.git

pushd intel-optimization-for-horovod
git checkout r0.28.1.6
git submodule init
git submodule update

# ANL oneapi modulefiles sets this env var, must unset for tensorflow horovod plugin build to suceed on non-compute node
unset ONEAPI_DEVICE_SELECTOR
CC=icx CXX=icpx python setup.py bdist_wheel
pip install --upgrade --no-deps --force-reinstall dist/*whl

popd

echo ""
echo "Completed build and installing horovod wheel"
echo ""

