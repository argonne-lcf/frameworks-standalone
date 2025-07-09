#!/bin/bash
##################################
# This script is used to install:
# - PyTorch 2.7
# - Intel Extension for PyTorch
# - Torch CCL
# on the Aurora system.
#
# It creates a new conda environment,
# installs the necessary packages,
# and activates the environment.
#
# - Usage: `./pt27.sh <envdir>`
#
# - Parameters:
#   - `envdir`: Directory where the conda 
#     environment will be created.
#
# - Example:
#
#   ```bash
#   git clone https://github.com/argonne-lcf/frameworks-standalone
#   cd frameworks-standalone
#   # *Be sure to use a path _you_ have write access to!
#   envdir="/flare//miniforge/$(date +%Y%m%d-%H%M%S)-test"
#   bash Aurora/pytorch/pt27.sh "${envdir}"
#   ```
#
##################################

if [[ "${DEBUG:-0}" == "1" ]]; then
    set -x
    set -euo pipefail
fi

# Create a new conda environment at the specified path.
# Usage: create_new_conda_env <envdir>
# Parameters:
# - envdir: The path where the conda environment will be created.
create_new_conda_env() {
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: $0 <envdir>"
        return 1
    fi
    envdir="$(realpath "$1")"
    echo "Creating conda environment in: ${envdir}"
    # Check if the environment already exists
    if [[ -d "${envdir}" ]] && [[ -n "$(ls -A "${envdir}")" ]]; then
        echo "Error: Environment directory ${envdir} already exists."
        return 1
    fi
    mkdir -p "${envdir}"
    export CONDA_ENV="${envdir}"
    export CONDA_PKGS_DIRS="${envdir}/.conda/pkgs"
    export PIP_CACHE_DIR="${envdir}/.pip"
    conda create -y -p "${envdir}" --override-channels \
        --channel https://software.repos.intel.com/python/conda/linux-64 \
        --channel conda-forge \
        --insecure \
        --strict-channel-priority \
        --yes \
        --solver=libmamba \
        python=3.10
    return $?
}

# Set up the necessary modules for the environment.
# It unloads existing modules, loads the required ones, and sets environment variables.
# Usage: setup_modules
setup_modules() {
    module restore
    module unload oneapi mpich
    module use /soft/compilers/oneapi/2025.1.3/modulefiles
    module use /soft/compilers/oneapi/nope/modulefiles
    module add mpich/nope/develop-git.6037a7a
    module load cmake
    unset CMAKE_ROOT
    export A21_SDK_PTIROOT_OVERRIDE=/home/cchannui/debug5/pti-gpu-test/tools/pti-gpu/d5c2e2e
    module add oneapi/public/2025.1.3
}

# Set up the environment for installing:
# - PyTorch 2.7
# - Intel Extension for PyTorch
# - Torch CCL
# Usage: setup_env <envdir>
# Parameters:
# - envdir: Directory where the conda environment will be created.
setup_env() {
    source /opt/aurora/24.347.0/spack/unified/0.9.2/install/linux-sles15-x86_64/gcc-13.3.0/miniforge3-24.3.0-0-gfganax/bin/activate
    create_new_conda_env "$@"
    if [[ -z "${envdir}" ]]; then
        echo "Error: Environment path is not set. Please provide a valid environment directory and name."
        return 1
    fi
    conda activate "${envdir}"
}

# Install:
# - PyTorch
# - Intel Extension for PyTorch
# - Torch CCL
# from pre-built wheels.
# Usage: install_whls_and_deps
install_whls_and_deps() {
    whl_factory="/lus/flare/projects/Aurora_deployment/wheel_warehouse"

    # PyTorch 2.7 wheel directory and file
    pt_dir="${whl_factory}/pt2p7_py3p10p14_pti0p10p3"
    pt_whl="$(ls "$(dirname "${pt_dir}")"/*pt2p7*/*.whl)"

    # Intel Extension for PyTorch wheel directory and file
    ipex_dir="${whl_factory}/ipex_2p7_oneapi_2025p1p3_pti_0p10p3_python3p10p14_panos"
    ipex_whl="$(ls "$(dirname "${ipex_dir}")"/*ipex*/*.whl)"

    #  OneCCL Bindings for Pytorchwheel directory and file
    ccl_dir="${whl_factory}/torch_ccl_2p7_oneapi_2025p1p3_pti_0p10p3_python3p10p14"
    ccl_whl="$(ls "$(dirname "${ccl_dir}")"/*ccl*/*.whl)"

    # Install mpi4py
    CC=mpicc CXX=mpicxx python3 -m pip install "git+https://github.com/mpi4py/mpi4py"

    # Install requirements
    requirements_file="$(find "${whl_factory}" -name 'ipex_pytorch_2p7_combined_requirements.txt')"
    if [[ -z "${requirements_file}" ]]; then
        echo "Error: No requirements file found in ${whl_factory}."
        return 1
    else
        python3 -m pip install -r "${requirements_file}"
    fi

    # python3 -m pip uninstall -y numpy
    # python3 -m pip install numpy==1.26.4
    python3 -m pip install numpy==1.26.4
    
    # python3 -m pip install --no-deps --no-cache-dir --force-reinstall "${pt_whl}"
    # python3 -m pip install --no-deps --no-cache-dir --force-reinstall "${ipex_whl}"
    # python3 -m pip install --no-deps --no-cache-dir --force-reinstall "${ccl_whl}"
    for whl in "${pt_whl}" "${ipex_whl}" "${ccl_whl}"; do
        if [[ ! -f "${whl}" ]]; then
            echo "Error: Wheel file ${whl} does not exist."
            return 1
        else
            echo "Found wheel file: ${whl}"
            python3 -m pip install --no-deps --no-cache-dir --force-reinstall "${whl}"
        fi
    done
}

# Test the installation of PyTorch, Intel Extension for PyTorch, and Torch CCL.
# Usage: test_install
# test_install
test_install() {
    python3 -c 'import torch; print(torch.__file__); print(*torch.__config__.show().split("\n"), sep="\n") ; print(f"{torch.__version__=}"); print(f"{torch.xpu.is_available()=}"); print(f"{torch.xpu.device_count()=}") ; import torch.distributed; print(f"{torch.distributed.is_xccl_available()=}"); import torch; import intel_extension_for_pytorch as ipex; print(f"{torch.__version__=}"); print(f"{ipex.__version__=}"); import oneccl_bindings_for_pytorch as oneccl_bpt; print(f"{oneccl_bpt.__version__=}") ; [print(f"[{i}]: {torch.xpu.get_device_properties(i)}") for i in range(torch.xpu.device_count())]'
}

# This function runs the simple `ezpz-test` to verify distributed training functionality.`
# Usage: run_ezpz_test
run_ezpz_test() {
    # shellcheck disable=SC1090
    NO_COLOR=1 source <(curl -L https://bit.ly/ezpz-utils) && ezpz_setup_env
    python3 -m pip install "git+https://github.com/saforem2/ezpz" --require-virtualenv
    ezpz-test
}

# This function is the main entry point of the script.
# Usage: main <envdir>
# Parameters:
# - envdir: Directory where the conda environment will be created.
main() {
    if ! setup_env "$@"; then
        echo "Failed to set up the environment. Please check the output for details."
        return 1
    fi
    setup_modules || return 1
    install_whls_and_deps || return 1
    test_install || return 1
    #########################################################
    # NOTE: [sam @ 2025-07-04]
    # (re-?) Setting ZE_FLAT_DEVICE_HIERARCHY to FLAT below
    export ZE_FLAT_DEVICE_HIERARCHY=FLAT
    #########################################################
    run_ezpz_test || {
        echo "ezpz-test failed. Please check the output for details."
        return 1
    }
    return $?
}

main "$@"
