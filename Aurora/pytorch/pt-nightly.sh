#!/bin/bash --login
#
# This script is used to build and install:
# - pytorch/
#   - pytorch
#   - torchvision
#   - torchaudio
#   - torchdata
#   - Torch AO
#   - TorchTune
# - intel/
#   - intel-extension-for-pytorch
#   - torch-ccl
# - mpi4py/mpi4py
# - ~~h5py/h5py~~[^disabled]
# on the Intel Aurora system.
#
# [^disabled]: Until new `hdf5` module available
#
# It creates a new conda environment,
# installs the necessary packages,
# and activates the environment.
#
# - Usage: `./pt-nightly.sh <conda_env_dir> [<build_dir>]`
#
# - Parameters:
#   - `<conda_env_dir>`: Directory where the conda environment will be created.
#   - `[<build_dir>]`: Directory where our libraries will be built.
#
# - Example(s):
#
#   - Specifying only the conda environment directory:
#
#     ```bash
#     ./pt-nightly.sh "/path/to/conda/env"
#     ```
#
#   - Specifying both directories (useful for debugging or continuing a previous build):
#
#     ```bash
#     bdir="/path/to/build"
#     edir="/path/to/conda/env"
#     ./pt-nightly.sh "$edir" "$bdir"
#     ```

# Exit immediately if a command exits with a non-zero status.
if [[ "${DEBUG:-0}" == "1" ]]; then
    set -o errexit # abort on nonzero exit status
    set -o nounset # abort on unset variables
    set -o pipefail # dont hide errors in pipes
fi

readonly PT="nightly"
DEFAULT_PYTHON_VERSION="${DEFAULT_PYTHON_VERSION:-3.11}"
START_TIME="$(tstamp)"

# source the ezpz-utils script for logging and other utilities
# provides, e.g.:
# log_message INFO "info"  # or DEBUG, WARN, ERROR, ...
#
# shellcheck disable=SC1090
NO_COLOR=1 source <(curl -L https://bit.ly/ezpz-utils) || {
    log_message ERROR "Failed to source ezpz-utils script. Please check your internet connection."
    exit 1
}


# --- Helper Functions ---
install_micromamba() {
    "${SHELL}" <(curl -L micro.mamba.pm/install.sh)
}

install_uv() {
    curl -LsSf https://astral.sh/uv/install.sh | sh
}

# Helper function to get timestamp
tstamp() {
    date +"%Y-%m-%d-%H%M%S"
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
    #======================================================
    # [2025-07-06][NOTE][sam]: Not exported elsewhere (??)
    export ZE_FLAT_DEVICE_HIERARCHY=FLAT
    #======================================================
}

# Function to activate (or create, if not found) a conda environment using
# [micromamba](https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html)
#
# - Usage: `activate_or_create_micromamba_env <envdir> [<python_version>]`
# - Parameters:
#   - `<envdir>`: Directory to look for the conda environment.
#   - `[<python_version>]`: Optional Python version to use for the environment.
#     If not specified, it defaults to the value of `${DEFAULT_PYTHON_VERSION:-3.11}`.
activate_or_create_micromamba_env() {
    if ! command -v micromamba &>/dev/null; then
        log_message INFO "micromamba not found. Installing micromamba..."
        install_micromamba || {
            log_message INFO "Failed to install micromamba. Please ensure you have curl installed."
            return 1
        }
    fi
    if [[ "$#" -eq 2 ]]; then
        log_message INFO "Received two arguments: envdir=$1, python_version=$2"
        envdir="$(realpath "$1")"
        python_version="$2"
    elif [[ "$#" -eq 1 ]]; then
        log_message INFO "Received one argument: envdir=$1"
        envdir="$(realpath "$1")"
        python_version="${DEFAULT_PYTHON_VERSION:-3.11}"
    else
        log_message INFO "Usage: $0 <envdir> [<python_version>]"
        log_message INFO "If no python version is specified, it defaults to ${DEFAULT_PYTHON_VERSION:-3.11}."
        return 1
    fi

    # Initialize shell for micromamba
    shell_type="$(basename "${SHELL}")"
    eval "$(micromamba shell hook --shell "${shell_type}")"
    # Check if the environment already exists
    if [[ -d "${envdir}" ]] && [[ -n "$(ls -A "${envdir}")" ]]; then
        log_message INFO "Found existing conda environment at ${envdir}. Activating it..."
        micromamba activate "${envdir}" || {
            log_message INFO "Failed to activate existing conda environment at ${envdir}."
            return 1
        }
    else
        log_message INFO "Creating conda environment in: ${envdir}"
        micromamba create --prefix "${envdir}" \
            --yes \
            --verbose \
            --override-channels \
            --channel https://software.repos.intel.com/python/conda/linux-64 \
            --channel conda-forge \
            --strict-channel-priority \
            "python=${python_version}" || {
            log_message INFO "Failed to create conda environment at ${envdir}."
            return 1
        }
        # Activate the newly created environment
        log_message INFO "Activating the conda environment at ${envdir}..."
        micromamba activate "${envdir}" || {
            log_message INFO "Failed to create or activate conda environment at ${envdir}."
            return 1
        }
    fi
}

# Generic function to clone a GitHub repository and build a wheel from it.
# NOTE: THIS HASNT BEEN TESTED YET
# But, something like this should work and could _possibly_ be used as a
# generic replacement instead of having to manually build each library
# one-by-one as we're doing now.
build_bdist_wheel_from_github_repo() {
    if [[ "$#" -ne 1 ]]; then
        log_message INFO "Usage: $0 <wheel_name>"
        return 1
    fi
    local repo_url="$1"
    git clone "${repo_url}" && cd "${repo_url##*/}" || return 1
    git submodule sync
    git submodule update --init --recursive
    if [[ -f "requirements.txt" ]]; then
        uv pip install -r requirements.txt
    fi
    if [[ -f "setup.py" ]]; then
        log_message INFO "Building wheel from setup.py..."
        uv pip install --upgrade pip setuptools wheel
        python3 setup.py bdist_wheel
        uv pip install dist/*.whl
    elif [[ -f "pyproject.toml" ]]; then
        log_message INFO "Building wheel from pyproject.toml..."
        python3 -m build --installer=uv
    fi
    uv pip install dist/*.whl || {
        log_message INFO "Failed to install the built wheel."
        return 1
    }
    log_message INFO "Successfully built and installed the wheel from ${repo_url}."
    cd - || return 1
}

# Function to prepare a repository in the specified build directory.
#
# - Usage: prepare_repo_in_build_dir `<build_dir>` `<repo_url>`
#   Where <build_dir> is the directory where the repository will be cloned.
#
# - Example:
#
#   ```bash
#   prepare_repo_in_build_dir build-2025-07-05-203137 "https://github.com/pytorch/pytorch"
#   ```
prepare_repo_in_build_dir() {
    # build_dir, repo_url
    if [[ "$#" -ne 2 ]]; then
        log_message INFO "Usage: $0 <build_dir> <repo_url>"
        log_message INFO "Where <build_dir> is the directory where the repository will be cloned."
        return 1
    fi
    local bd
    bd="$(realpath "$1")"
    local src
    src="$2"
    local name
    name="${src##*/}" # Extract the repository name from the URL
    local fp
    fp="${bd}/${name}" # Full path
    if [[ ! -d "${fp}" ]]; then
        log_message INFO "Cloning ${name} from ${src} into ${fp}"
        git clone "${src}" "${fp}" || {
            log_message INFO "Failed to clone ${src}."
            return 1
        }
    else
        log_message INFO "${name} already exists in ${bd}. Skipping clone."
    fi
    cd "${fp}" || {
        log_message INFO "Failed to change directory to ${fp}. Please ensure it exists."
        return 1
    }
    git submodule sync
    git submodule update --init --recursive
    cd - || return 1
}

# Function to check if the wheel file already exists in the build directory.
# - Usage: check_if_already_built `<libdir>`
check_if_already_built() {
    # Check if the wheel file already exists in the build directory
    if [[ "$#" -ne 1 ]]; then
        log_message INFO "Usage: $0 libdir"
        return 1
    fi

    local ldir; ldir="$(realpath "$1")"
    log_message INFO "Checking for existing wheels in ${ldir}/dist..."

    if [[ -d "${ldir}/dist" ]] && [[ -n "$(ls -A "${ldir}/dist")" ]]; then
        log_message INFO "Found existing wheels in ${ldir}/dist:"
        ls "${ldir}/dist"/*.whl
        return 0
    else
        return 1
    fi
}

# Function to build PyTorch from source in the specified build directory.
# Usage: build_pytorch <build_dir>
# Where <build_dir> is the directory where PyTorch will be built.
#
# Takes ~ 2 hrs
#
# - Usage: build_pytorch <build_dir>
build_pytorch() {
    if [[ "$#" -ne 1 ]]; then
        log_message INFO "Usage: $0 <build_dir>"
        log_message INFO "Where <build_dir> is the directory where PyTorch will be built."
        return 1
    fi
    build_dir="$(realpath "$1")"
    pt_url="https://github.com/pytorch/pytorch"
    prepare_repo_in_build_dir "${build_dir}" "${pt_url}" || {
        log_message INFO "Failed to prepare PyTorch repository."
        return 1
    }

    if check_if_already_built "${build_dir}/pytorch"; then
        log_message INFO "PyTorch wheel already exists. Skipping build."
        return 0
    fi

    log_message INFO "Navigating into ${build_dir}/pytorch/"
    cd "${build_dir}/pytorch" || return 1

    log_message INFO "Installing PyTorch build dependencies..."
    uv pip install cmake ninja
    uv pip install -r requirements.txt
    uv pip install mkl-static mkl-include

    log_message INFO "Making triton..."
    export USE_XPU=1 # for Intel GPU support
    make triton || return 1

    log_message INFO "Setting environment variables for PyTorch build..."
    CC=$(which gcc)
    export CC
    CXX=$(which g++)
    export CXX
    export REL_WITH_DEB_INFO=1
    export USE_CUDA=0
    export USE_ROCM=0
    export USE_MKLDNN=1
    export USE_MKL=1
    export USE_CUDNN=0
    export USE_FBGEMM=1
    export USE_NNPACK=1
    export USE_QNNPACK=1
    export USE_NCCL=0
    export BUILD_CAFFE2_OPS=0
    export BUILD_TEST=0
    export USE_DISTRIBUTED=1
    export USE_NUMA=0
    export USE_MPI=1
    export USE_XPU=1
    export USE_XCCL=1
    export INTEL_MKL_DIR=$MKLROOT
    export USE_AOT_DEVLIST='pvc'
    export TORCH_XPU_ARCH_LIST='pvc'
    export OCLOC_VERSION=24.39.1

    log_message INFO "Checking compilers:"
    log_message INFO "Using gcc from: $(which -a gcc)"
    log_message INFO "Using g++ from: $(which -a g++)"

    log_message INFO "Building PyTorch (this may take ~30 minutes)..."
    python3 setup.py bdist_wheel | tee "torch-build-whl-$(tstamp).log"
    log_message INFO "Installing PyTorch wheel..."
    uv pip install dist/*.whl
    cd - || return 1
}

# Function to install optional PyTorch libraries
# - Usage: install_optional_pytorch_libs
install_optional_pytorch_libs() {
    log_message INFO "Installing torchvision and torchaudio with no dependencies for XPU..."
    uv pip install torchvision torchaudio --no-deps --index-url https://download.pytorch.org/whl/xpu
    log_message INFO "Installing torchdata with no dependencies..."
    uv pip install torchdata --no-deps
}

# Function to build Intel Extension for PyTorch
# - Usage: build_ipex <build_dir>
build_ipex() {
    if [[ "$#" -ne 1 ]]; then
        log_message INFO "Usage: $0 <build_dir>"
        log_message INFO "Where <build_dir> is the directory where Intel Extension for PyTorch will be built."
        return 1
    fi
    build_dir="$(realpath "$1")"
    ipex_url="https://github.com/intel/intel-extension-for-pytorch"
    prepare_repo_in_build_dir "${build_dir}" "${ipex_url}" || {
        log_message INFO "Failed to prepare Intel Extension for PyTorch repository."
        return 1
    }
    # Check if the wheel file already exists in the build directory
    if check_if_already_built "${build_dir}/intel-extension-for-pytorch"; then
        log_message INFO "Intel Extension for PyTorch wheel already exists. Skipping build."
        return 0
    fi

    cd "${build_dir}/intel-extension-for-pytorch" || return 1
    git checkout xpu-main

    log_message INFO "Syncing and updating git submodules for Intel Extension for PyTorch..."
    git submodule sync
    git submodule update --init --recursive

    log_message INFO "Installing Intel Extension for PyTorch dependencies..."
    uv pip install -r requirements.txt
    uv pip install --upgrade pip setuptools wheel build black flake8

    log_message INFO "Building Intel Extension for PyTorch (IPEX)..."
    MAX_JOBS=48 CC=$(which gcc) CXX=$(which g++) INTELONEAPIROOT="${ONEAPI_ROOT}" python3 setup.py bdist_wheel | tee "ipex-build-whl-$(tstamp).log"
    log_message INFO "Installing Intel Extension for PyTorch wheel..."
    uv pip install dist/*.whl
    cd - || return 1
}

# Function to build torch-ccl
# - Usage: build_torch_ccl <build_dir>
build_torch_ccl() {
    if [[ "$#" -ne 1 ]]; then
        log_message INFO "Usage: $0 <build_dir>"
        log_message INFO "Where <build_dir> is the directory where torch-ccl will be built."
        return 1
    fi
    build_dir="$(realpath "$1")"
    ccl_url="https://github.com/intel/torch-ccl"
    prepare_repo_in_build_dir "${build_dir}" "${ccl_url}" || {
        log_message INFO "Failed to prepare torch-ccl repository."
        return 1
    }

    # Check if the wheel file already exists in the build directory
    if check_if_already_built "${build_dir}/torch-ccl"; then
        log_message INFO "torch-ccl wheel already exists. Skipping build."
        return 0
    fi

    cd "${build_dir}/torch-ccl" || return 1

    log_message INFO "Installing torch-ccl dependencies..."
    uv pip install -r requirements.txt

    log_message INFO "Building torch-ccl..."
    ONECCL_BINDINGS_FOR_PYTORCH_BACKEND=xpu INTELONEAPIROOT="${ONEAPI_ROOT}" USE_SYSTEM_ONECCL=ON COMPUTE_BACKEND=dpcpp python3 setup.py bdist_wheel | tee "torch-ccl-build-whl-$(tstamp).log"

    log_message INFO "Installing torch-ccl wheel..."
    uv pip install dist/*.whl
    cd - || return 1
}

# Function to build mpi4py
# - Usage: build_mpi4py <build_dir>
build_mpi4py() {
    if [[ "$#" -ne 1 ]]; then
        log_message INFO "Usage: $0 <build_dir>"
        log_message INFO "Where <build_dir> is the directory where mpi4py will be built."
        return 1
    fi
    build_dir="$(realpath "$1")"
    mpi4py_url="https://github.com/mpi4py/mpi4py"
    prepare_repo_in_build_dir "${build_dir}" "${mpi4py_url}" || {
        log_message INFO "Failed to prepare mpi4py repository."
        return 1
    }
    # Check if the wheel file already exists in the build directory
    if check_if_already_built "${build_dir}/mpi4py"; then
        log_message INFO "mpi4py wheel already exists. Skipping build."
        return 0
    fi
    cd "${build_dir}/mpi4py" || return 1
    log_message INFO "Building mpi4py..."
    CC=mpicc CXX=mpicxx python3 setup.py bdist_wheel | tee "mpi4py-build-whl-$(tstamp).log"
    log_message INFO "Installing mpi4py wheel..."
    uv pip install dist/*.whl
    log_message INFO "Showing mpi4py configuration (for verification):"
    python3 -c 'import mpi4py; print(mpi4py.get_config())'
    log_message INFO "mpi4py installed successfully."
    cd - || return 1
}

# Function to build h5py
# - Usage: build_h5py <build_dir>
build_h5py() {
    if [[ "$#" -ne 1 ]]; then
        log_message INFO "Usage: $0 <build_dir>"
        log_message INFO "Where <build_dir> is the directory where h5py will be built."
        return 1
    fi
    build_dir="$(realpath "$1")"
    h5py_url="https://github.com/h5py/h5py"
    prepare_repo_in_build_dir "${build_dir}" "${h5py_url}" || {
        log_message INFO "Failed to prepare h5py repository."
        return 1
    }

    # Check if the wheel file already exists in the build directory
    if check_if_already_built "${build_dir}/h5py"; then
        log_message INFO "h5py wheel already exists. Skipping build."
        return 0
    fi

    log_message INFO "Installing h5py..."
    module load hdf5
    cd "${build_dir}/h5py" || return 1
    CC=mpicc CXX=mpicxx HDF5_MPI="ON" HDF5_DIR="${HDF5_ROOT}" python3 setup.py bdist_wheel | tee "h5py-build-whl-$(tstamp).log"

    log_message INFO "Installing h5py wheel..."
    uv pip install dist/*.whl

    log_message INFO "Showing h5cc configuration (for verification):"
    h5cc -showconfig
    cd - || return 1
}

# Function to build torch / ao
# - Usage: build_torch_ao <build_dir>
build_torch_ao() {
    if [[ "$#" -ne 1 ]]; then
        log_message INFO "Usage: $0 <build_dir>"
        log_message INFO "Where <build_dir> is the directory where torch/ao will be built."
        return 1
    fi
    build_dir="$(realpath "$1")"
    ao_url="https://github.com/pytorch/ao"
    prepare_repo_in_build_dir "${build_dir}" "${ao_url}" || {
        log_message INFO "Failed to prepare torch/ao repository."
        return 1
    }
    # Check if the wheel file already exists in the build directory
    if check_if_already_built "${build_dir}/ao"; then
        log_message INFO "torch/ao wheel already exists. Skipping build."
        return 0
    fi

    log_message INFO "Building torch/ao..."
    cd "${build_dir}/ao" || return 1
    USE_CUDA=0 USE_XPU=1 USE_XCCL=1 python3 setup.py bdist_wheel | tee "torchao-build-whl-$(tstamp).log"
    log_message INFO "Installing torch/ao wheel..."
    uv pip install dist/*.whl
    cd - || return 1
}

# Function to build TorchTune and download model
# - Usage: build_torchtune <build_dir>
build_torchtune() {
    if [[ "$#" -ne 1 ]]; then
        log_message INFO "Usage: $0 <build_dir>"
        log_message INFO "Where <build_dir> is the directory where TorchTune will be built."
        return 1
    fi
    build_dir="$(realpath "$1")"
    torchtune_url="https://github.com/pytorch/torchtune"
    prepare_repo_in_build_dir "${build_dir}" "${torchtune_url}" || {
        log_message INFO "Failed to prepare TorchTune repository."
        return 1
    }
    # Check if the wheel file already exists in the build directory
    if check_if_already_built "${build_dir}/torchtune"; then
        log_message INFO "TorchTune wheel already exists. Skipping build."
        return 0
    fi

    log_message INFO "Installing TorchTune in editable mode..."
    cd "${build_dir}/torchtune" || return 1
    USE_CUDA=0 USE_XPU=1 USE_XCCL=1 python3 -m build --installer=uv | tee "torchtune-build-$(tstamp).log"
    log_message INFO "Installing TorchTune wheel..."
    uv pip install dist/*.whl
    cd - || return 1
}

# Function to verify installation
# - Usage: verify_installation
verify_installation() {
    log_message INFO "--- Verifying Installation ---"
    log_message INFO "Running Python script to verify PyTorch and Intel Extension for PyTorch installation..."
    python3 -c 'import torch; print(torch.__file__); print(*torch.__config__.show().split("\n"), sep="\n") ; print(f"{torch.__version__=}"); print(f"{torch.xpu.is_available()=}"); print(f"{torch.xpu.device_count()=}") ; import torch.distributed; print(f"{torch.distributed.is_xccl_available()=}"); import torch; import intel_extension_for_pytorch as ipex; print(f"{torch.__version__=}"); print(f"{ipex.__version__=}"); import oneccl_bindings_for_pytorch as oneccl_bpt; print(f"{oneccl_bpt.__version__=}") ; [print(f"[{i}]: {torch.xpu.get_device_properties(i)}") for i in range(torch.xpu.device_count())]'
}

# This function runs the simple `ezpz-test` to verify distributed training
# functionality.
# - Usage: run_ezpz_test
run_ezpz_test() {
    # shellcheck disable=SC1090
    NO_COLOR=1 source <(curl -L https://bit.ly/ezpz-utils) && ezpz_setup_env
    python3 -m pip install "git+https://github.com/saforem2/ezpz" --require-virtualenv
    ezpz-test
}

# Function to set up the environment.
# It:
# - installs `uv` and `micromamba` if they are not already installed
# - creates or activates a conda environment
# - loads necessary modules
# - sets appropriate environment variables
# - Usage: setup_environment <conda_env_dir>
setup_environment() {
    log_message INFO "Setting up environment..."
    if [[ "$#" -eq 1 ]]; then
        conda_env_dir="$(realpath "$1")"
    else
        log_message INFO "Usage: $0 <conda_env_dir>"
    fi
    # ---- Install {uv, micromamba} if necessary
    # Ensure uv is installed
    if ! command -v uv &>/dev/null; then
        log_message INFO "uv not found. Installing uv..."
        install_uv || {
            log_message INFO "Failed to install uv. Please ensure you have curl installed."
            return 1
        }
    fi
    export UV_CACHE_DIR="${UV_CACHE_DIR:-${conda_env_dir}/.cache/uv}"
    # Ensure micromamba is installed
    if ! command -v micromamba &>/dev/null; then
        log_message INFO "micromamba not found. Installing micromamba..."
        install_micromamba || {
            log_message INFO "Failed to install micromamba. Please ensure you have curl installed."
            return 1
        }
    fi

    # ---- Setup Environment
    # Took < 10 min
    log_message INFO "Creating (or activating) conda environment at: ${conda_env_dir}"
    log_message INFO "Using Python version: ${DEFAULT_PYTHON_VERSION}"
    activate_or_create_micromamba_env "${conda_env_dir}" "${DEFAULT_PYTHON_VERSION}" || {
        log_message INFO "Failed to create or activate conda environment at ${conda_env_dir}."
        return 1
    }
    # Load necessary modules and set appropriate environment variables
    setup_modules || {
        log_message INFO "Failed to load necessary modules. Please check the output for details."
        return 1
    }
    log_message INFO "Environment setup complete. Conda environment is ready at: ${conda_env_dir}"
}

# Function to build and install all libraries.
# It:
# - builds PyTorch and its optional libraries
# - builds Intel Extension for PyTorch
# - builds torch-ccl
# - builds mpi4py
# - builds h5py (if available)
# - builds torch/ao
# - builds TorchTune
#
# - Usage: build_and_install_libraries <build_dir>
build_and_install_libraries() {
    log_message INFO "Building libraries..."
    if [[ "$#" -ne 1 ]]; then
        log_message INFO "Usage: $0 <build_dir>"
        log_message INFO "Where <build_dir> is the directory where our libraries will be built."
        return 1
    fi
    build_dir="$(realpath "$1")"
    # Ensure the build directory exists
    if [[ ! -d "${build_dir}" ]]; then
        log_message INFO "Creating build directory: ${build_dir}"
        mkdir -p "${build_dir}" || {
            log_message INFO "Failed to create build directory ${build_dir}."
            return 1
        }
    fi
    log_message INFO "Build directory is set to: ${build_dir}"

    # ---- Build and Install Libraries
    # Took ~ 2 hrs
    build_pytorch "${build_dir}" || {
        log_message INFO "Failed to build PyTorch. Please check the output for details."
        return 1
    }
    # Took < 1 min
    install_optional_pytorch_libs || {
        log_message INFO "Failed to install optional PyTorch libraries. Please check the output for details."
        return 1
    }
    # Took ~ 1 hr
    # (and 3 tries, see \[IPEX Build Notes above\])
    build_ipex "${build_dir}" || {
        log_message INFO "Failed to build Intel Extension for PyTorch. Please check the output for details."
        return 1
    }
    # Took 0h:03m:09s
    build_torch_ccl "${build_dir}" || {
        log_message INFO "Failed to build torch-ccl. Please check the output for details."
        return 1
    }
    # Took 0h:01m:43s
    build_mpi4py "${build_dir}" || {
        log_message INFO "Failed to build mpi4py. Please check the output for details."
        return 1
    }

    # [BROKEN AS OF 2025-07-06]
    # (`module load hdf5` not supported ??)
    # build_h5py "${build_dir}" || {
    #     log_message INFO "Failed to build h5py. Please check the output for details."
    #     return 1
    # }

    # Took 0h:01m:08s
    build_torch_ao "${build_dir}" || {
        log_message INFO "Failed to build torch/ao. Please check the output for details."
        return 1
    }
    # Took 0h:00m:42s
    build_torchtune "${build_dir}" || {
        log_message INFO "Failed to build TorchTune. Please check the output for details."
        return 1
    }
    log_message INFO "All libraries built and installed successfully in ${build_dir}."
}

# Main function to orchestrate the build and installation process.
#
# - Usage: `main <conda_env_dir> [<build_dir>]`
#
# - Parameters:
#   - `<conda_env_dir>`: Directory where the conda environment will be created.
#   - `[<build_dir>]`: Directory where our libraries will be built.
#
# - Example:
#   - Specifying only the conda environment directory:
#
#     ```bash
#     main "/path/to/conda/env"
#     ```
#
#   - Specifying both directories:
#
#     ```bash
#     bdir="/path/to/build"
#     edir="/path/to/conda/env"
#     main "$edir" "$bdir"
#     ```
main() {
    # ---- Parse Arguments
    if [[ "$#" -eq 2 ]]; then
        conda_env_dir="$(realpath "$1")"
        build_dir="$(realpath "$2")"
    elif [[ "$#" -eq 1 ]]; then
        conda_env_dir="$(realpath "$1")"
        TSTAMP=$(tstamp)
        build_dir="$(pwd)/builds/${PT}/${TSTAMP}"
        log_message INFO "No build directory specified. Using default: ${build_dir}"
        mkdir -p "${build_dir}"
    else
        log_message INFO "Usage: $0 <conda_env_dir> [<build_dir>]"
        log_message INFO "Where <conda_env_dir> is the directory where the conda environment will be created."
        log_message INFO "And [<build_dir>] is the directory where our libraries will be built."
        log_message INFO "If no build directory is specified, a default one will be created in the current working directory."
        return 1
    fi

    # ---- Setup Environment
    setup_environment "${conda_env_dir}" || {
        log_message INFO "Failed to set up the environment. Please check the output for details."
        return 1
    }

    # ---- Build and Install Libraries
    build_and_install_libraries "${build_dir}" || {
        log_message INFO "Failed to build and install libraries. Please check the output for details."
        return 1
    }

    # ---- Verify Installation
    verify_installation || {
        log_message INFO "Installation verification failed. Please check the output for details."
        return 1
    }

    # ---- Test simple distributed training functionality
    run_ezpz_test || {
        log_message INFO "ezpz-test failed. Please check the output for details."
        return 1
    }

    log_message INFO "All build and installation steps completed successfully!"
}


if [[ -n "${NO_BUILD:-}" ]]; then
    log_message INFO "Skipping build steps as NO_BUILD is set."
else
    # Ensure the script is run with the necessary arguments
    if [[ "$#" -lt 1 ]]; then
        log_message INFO "Usage: $0 <conda_env_dir> [<build_dir>]"
        log_message INFO "Please provide at least the conda environment directory."
        exit 1
    fi
    log_message INFO "Starting build..."
    log_message INFO "Log will be saved to install-pt${PT}-${START_TIME}.log"
    main "$@" | tee "install-pt${PT}-${START_TIME}.log" || {
        log_message INFO "Build failed. Please check the log for details."
        exit 1
    }
fi
