#!/bin/bash
# This script is used to install PyTorch 2.7, Intel Extension for PyTorch, and Torch CCL on the Aurora system.
# It creates a new conda environment, installs the necessary packages, and activates the environment.
#
# Usage: bash install_pt2p7.sh <envdir>
#
# Parameters:
# - envdir: Directory where the conda environment will be created.

if [[ "${DEBUG:-0}" == "1" ]]; then
    set -x
    set -euo pipefail
fi

# Create a new conda environment at the specified path.
# Usage: create_new_conda_env <envpath>
# Parameters:
# - envpath: The path where the conda environment will be created.
create_new_conda_env() {
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: $0 <envpath>"
        return 1
    fi
    envpath="$(realpath "$1")"
    echo "Creating conda environment in: ${envpath}"
    # Check if the environment already exists
    if [[ -d "${envpath}" ]] && [[ -n "$(ls -A "${envpath}")" ]]; then
        echo "Error: Environment directory ${envpath} already exists."
        return 1
    fi
    mkdir -p "${envpath}"
    export CONDA_ENV="${envpath}"
    export CONDA_PKGS_DIRS="${envpath}/.conda/pkgs"
    export PIP_CACHE_DIR="${envpath}/.pip"
    conda create -y -p "${envpath}" --override-channels \
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
    if [[ -z "${envpath}" ]]; then
        echo "Error: Environment path is not set. Please provide a valid environment directory and name."
        return 1
    fi
    conda activate "${envpath}"
}

# Install:
# - PyTorch
# - Intel Extension for PyTorch
# - Torch CCL
# from pre-built wheels.
# Usage: install_whls_and_deps
install_whls_and_deps() {
    PYTORCH_WHEEL_LOC=/lus/flare/projects/Aurora_deployment/wheel_warehouse/pt2p7_py3p10p14_pti0p10p3
    IPEX_WHEEL_LOC=/lus/flare/projects/Aurora_deployment/wheel_warehouse/ipex_2p7_oneapi_2025p1p3_pti_0p10p3_python3p10p14_panos
    TORCH_CCL_WHEEL_LOC=/lus/flare/projects/Aurora_deployment/wheel_warehouse/torch_ccl_2p7_oneapi_2025p1p3_pti_0p10p3_python3p10p14
    WHEEL_FACTORY=$(dirname ${PYTORCH_WHEEL_LOC})
    PT_WHL="$(ls "$(dirname "${PYTORCH_WHEEL_LOC}")"/*pt2p7*/*.whl)"
    IPEX_WHL="$(ls "$(dirname "${IPEX_WHEEL_LOC}")"/*ipex*/*.whl)"
    TORCH_CCL_WHL="$(ls "$(dirname "${TORCH_CCL_WHEEL_LOC}")"/*ccl*/*.whl)"

    requirements_file="$(find "${WHEEL_FACTORY}" -name 'ipex_pytorch_2p7_combined_requirements.txt')"
    if [[ -z "${requirements_file}" ]]; then
        echo "Error: No requirements file found in ${WHEEL_FACTORY}."
        return 1
    else
        python3 -m pip install -r "${requirements_file}"
    fi
    python3 -m pip uninstall -y numpy
    python3 -m pip install numpy==1.26.4
    python3 -m pip install --no-deps --no-cache-dir --force-reinstall "${PT_WHL}"
    python3 -m pip install --no-deps --no-cache-dir --force-reinstall "${IPEX_WHL}"
    python3 -m pip install --no-deps --no-cache-dir --force-reinstall "${TORCH_CCL_WHL}"
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
    source <(curl -L https://bit.ly/ezpz-utils)
    NO_COLOR=1 ezpz_setup_env || return 1
    CC=mpicc CXX=mpicxx python3 -m pip install "git+https://github.com/mpi4py/mpi4py"
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
