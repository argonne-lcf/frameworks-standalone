#!/bin/bash

source "100-local_config.sh"

conda activate $CONDA_INSTALL_DIR/$CONDA_ENV_NAME
pip install --pre pytorch-triton-xpu==3.1.0+91b14bf559  --index-url https://download.pytorch.org/whl/nightly/xpu
#cd $TMP_WORK

#pip install --upgrade --no-deps --force-reinstall $WHEEL_LOC/pytorch_triton_xpu*whl


echo ""
echo "Completed build and installing triton wheel"
echo ""


