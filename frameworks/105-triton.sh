#!/bin/bash

source "800-local_config.sh"

conda activate $AURORA_PE_FRAMEWORKS_INSTALL_DIR/$AURORA_PE_FRAMEWORKS_ENV_NAME
pip install --pre pytorch-triton-xpu==3.1.0+91b14bf559  --index-url https://download.pytorch.org/whl/nightly/xpu
#cd $TMP_WORK

#pip install --upgrade --no-deps --force-reinstall $WHEEL_LOC/pytorch_triton_xpu*whl


echo ""
echo "Completed build and installing triton wheel"
echo ""


