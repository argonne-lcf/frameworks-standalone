#!/usr/bin/env bash
# After carefully construction your environment

source "800-local_config.sh"

LIST_FILE=frameworks_packages
LIST_FILE=reqs/frameworks_packages

function generate_list_files {
    conda list > $LIST_FILE
    grep -v '^#' | grep -v 'pypi$' | perl -pe 's/^(\S+)\s+(\S+).*/$1==$2/' >  $LIST_FILE.conda
    grep -v '^#' | grep 'pypi$' | perl -pe 's/^(\S+)\s+(\S+).*/$1==$2/' >  $LIST_FILE.pip

    cp /dev/null $LIST_FILE.extra
    cp $LIST_FILE.pip $LIST_FILE.pip.new
    for i in \
        intel-optimization-for-horovod \
        adorym \
        pytorch-triton-xpu \
        plasma \
        ; do
        grep $i $LIST_FILE.pip >> $LIST_FILE.extra
        sed -i "/$i/d" $LIST_FILE.pip.new
    done
    cp $LIST_FILE.pip.new $LIST_FILE.pip

    cp /dev/null $LIST_FILE.git
    echo "git+https://github.com/data-exchange/dxchange.git@v0.2.0" >> $LIST_FILE.git
    echo "git+https://github.com/DeepLearnPhysics/larcv3.git@v3.4.0" >> $LIST_FILE.git
        
    cp $LIST_FILE.pip $LIST_FILE.pip.new
    sed -i "/dxchange==/d" $LIST_FILE.pip.new
    sed -i "/larcv==/d" $LIST_FILE.pip.new
    cp $LIST_FILE.pip.new $LIST_FILE.pip

    cat $LIST_FILE.git $LIST_FILE.pip > $LIST_FILE.pip_combined
}

function build_conda_env {
    conda create -y -p ${AURORA_PE_FRAMEWORKS_INSTALL_DIR}/${AURORA_PE_FRAMEWORKS_ENV_NAME} $(cat $LIST_FILE.conda)
    conda activate ${AURORA_PE_FRAMEWORKS_INSTALL_DIR}/${AURORA_PE_FRAMEWORKS_ENV_NAME}
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
    for i in "${rm_conda_pkgs[@]}"; do
        conda remove --force --yes --prefix ${AURORA_PE_FRAMEWORKS_INSTALL_DIR}/${AURORA_PE_FRAMEWORKS_ENV_NAME} "$i" || true
    done
    pip install --no-deps --extra-index-url  https://pytorch-extension.intel.com/release-whl/stable/xpu/cn/ -r $LIST_FILE.pip
    pip install --no-deps --extra-index-url  https://pytorch-extension.intel.com/release-whl/stable/xpu/cn/ -r $LIST_FILE.git
}


#generate_list_files
build_conda_env

