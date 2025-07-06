#!/bin/bash --login


# Exit immediately if a command exits with a non-zero status.
if [[ "${DEBUG:-0}" == "1" ]]; then
    # set -e
    set -x
    set -euo pipefail
fi

NO_COLOR=1 source <(curl -L https://bit.ly/ezpz-utils) || return 1

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
}


# Function to create (or activate, if it exists) a conda environment using micromamba.
# If no arguments are provided, a default environment will be created in
# `${HOME}/micromamba/$(date +%Y%m%d-%H%M%S)` with Python 3.12
#
# - Usage: activate_or_create_mm_env [<envdir>] [<python_version>]
# - Example:
#
#   ```bash
#   ; activate_or_create_mm_env /flare/datascience/foremans/micromamba/envs/2025-07-pt28
#   # ...[clipped]...
#   took: 0h:07m:27s
#   ```
activate_or_create_mm_env() {
    if ! command -v micromamba &>/dev/null; then
        echo "micromamba not found. Installing micromamba..."
        install_micromamba || {
            echo "Failed to install micromamba. Please ensure you have curl installed."
            return 1
        }
    fi
    if [[ "$#" -eq 2 ]]; then
        echo "Received two arguments: envdir=$1, python_version=$2"
        envdir="$(realpath "$1")"
        python_version="$2"
    elif [[ "$#" -eq 1 ]]; then
        echo "Received one argument: envdir=$1"
        envdir="$(realpath "$1")"
        python_version="3.12"
    elif [[ "$#" -eq 0 ]]; then
        echo "Received no arguments, using default envdir and python version"
        envdir="${HOME}/miniforge/$(date +%Y%m%d-%H%M%S)"
        python_version="3.12"
    else
        echo "Usage: $0 [<envdir>] [<python_version>]"
        echo "If no arguments are provided, a default environment will be created in ${HOME}/micromamba/$(date +%Y%m%d-%H%M%S) with Python 3.10"
        return 1
    fi
    # Check if the environment already exists
    if [[ -d "${envdir}" ]] && [[ -n "$(ls -A "${envdir}")" ]]; then
        echo "Found existing conda environment at ${envdir}. Activating it..."
        micromamba activate "${envdir}" || {
            echo "Failed to activate existing conda environment at ${envdir}."
            return 1
        }
        return 0
    else
        echo "Creating conda environment in: ${envdir}"
        micromamba create --prefix "${envdir}" \
            --yes \
            --verbose \
            --override-channels \
            --channel https://software.repos.intel.com/python/conda/linux-64 \
            --channel conda-forge \
            --strict-channel-priority \
            "python=${python_version}" || {
                echo "Failed to create conda environment at ${envdir}."
                return 1
            }

        # Activate the newly created environment
        echo "Activating the conda environment at ${envdir}..."
        micromamba activate "${envdir}" || {
            echo "Failed to create or activate conda environment at ${envdir}."
            return 1
        }
    fi
}

# Function to activate the conda environment
# Usage: activate_or_create_conda_env [<envdir>] [<python_version>]
# If no arguments are provided, a default environment will be created in 
# ${HOME}/miniforge/$(date +%Y%m%d-%H%M%S) with Python 3.12
activate_or_create_conda_env() {
    if [[ "$#" -eq 2 ]]; then
        # envdir, python version
        envdir="$(realpath "$1")"
        python_version="$2"
    elif [[ "$#" -eq 1 ]]; then
        # envdir only
        envdir="$(realpath "$1")"
        python_version="3.12"
    elif [[ "$#" -eq 0 ]]; then
        # no arguments, use default envdir and python version
        envdir="${HOME}/miniforge/$(date +%Y%m%d-%H%M%S)-test"
        python_version="3.12"
    else
        echo "Usage: $0 [<envdir>] [<python_version>]"
        echo "If no arguments are provided, a default environment will be created in ${HOME}/miniforge/$(date +%Y%m%d-%H%M%S)-test with Python 3.10"
        return 1
    fi
    # Check if the environment already exists
    if [[ -d "${envdir}" ]] && [[ -n "$(ls -A "${envdir}")" ]]; then
        echo "Found existing conda environment at ${envdir}. Activating it..."
        conda activate "${envdir}" || {
            echo "Failed to activate existing conda environment at ${envdir}."
            return 1
        }
        return 0
    else
        echo "Creating conda environment in: ${envdir}"
        mkdir -p "${envdir}"

        # Load conda
        source /opt/aurora/24.347.0/spack/unified/0.9.2/install/linux-sles15-x86_64/gcc-13.3.0/miniforge3-24.3.0-0-gfganax/bin/activate
        if ! command -v conda &>/dev/null; then
            echo "Conda not found. Please ensure conda is installed and available in your PATH."
            return 1
        fi

        conda create -y -p "${envdir}" --override-channels \
            --channel https://software.repos.intel.com/python/conda/linux-64 \
            --channel conda-forge \
            --insecure \
            --strict-channel-priority \
            --yes \
            --solver=libmamba \
            python="${python_version}" || {
                echo "Failed to create conda environment at ${envdir}."
                return 1
            }

        conda activate "${envdir}" || {
                echo "Failed to create or activate conda environment at ${envdir}."
                return 1
        }
    fi
}



# clone_pytorch_in_build_dir() {
#     # if [[ "$#" -ne 1 ]]; then
#     #     echo "Usage: $0 <build_dir>"
#     #     return 1
#     # fi
#     # build_dir="$(realpath "$1")"
#     if [[ -z "${BUILD_DIR:-}" ]]; then
#         echo "Error: build_dir is not set. Please set the build_dir variable before calling this function."
#         return 1
#     fi
#
#     cd "${BUILD_DIR}" || {
#         echo "Failed to change directory to ${BUILD_DIR}. Please ensure it exists."
#         return 1
#     }
#     echo "Checking if pytorch/pytorch is already cloned in $BUILD_DIR"
#     # Check if the pytorch directory already exists
#     if [ -d "pytorch" ]; then
#         echo "pytorch/pytorch already exists in $BUILD_DIR. Skipping clone."
#         return 0
#     else
#         echo "pytorch/pytorch does not exist in $BUILD_DIR. Cloning..."
#         # If it doesn't exist, clone the repository
#         git 
#
#     fi
#     if [ ! -d "pytorch" ]; then
#         echo "Cloning pytorch/pytorch into $BUILD_DIR"
#         git clone https://github.com/pytorch/pytorch || {
#             echo "Failed to clone pytorch/pytorch."
#             return 1
#         }
#     fi
#     cd "${BUILD_DIR}/pytorch" || return 1
#
# }
#
#

build_bdist_wheel_from_github_repo() {
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: $0 <wheel_name>"
        return 1
    fi
    local repo_url="#1"
    git clone "${repo_url}" && cd  "${repo_url##*/}" || return 1
    git submodule sync
    git submodule update --init --recursive
    if [[ -f "requirements.txt" ]]; then
        uv pip install -r requirements.txt
    fi
    if [[ -f "setup.py" ]]; then
        echo "Building wheel from setup.py..."
        uv pip install --upgrade pip setuptools wheel
        python3 setup.py bdist_wheel
        uv pip install dist/*.whl
    elif [[ -f "pyproject.toml" ]]; then
        echo "Building wheel from pyproject.toml..."
        python3 -m build --installer=uv
    fi
    uv pip install dist/*.whl || {
        echo "Failed to install the built wheel."
        return 1
    }
    echo "Successfully built and installed the wheel from ${repo_url}."
    cd - || return 1
}


prepare_repo_in_build_dir() {
    # build_dir, repo_url
    if [[ "$#" -ne 2 ]]; then
        echo "Usage: $0 <build_dir> <repo_url>"
        echo "Where <build_dir> is the directory where the repository will be cloned."
        return 1
    fi
    # local build_dir repo_url repo_name
    local bd; bd="$(realpath "$1")"
    local src; src="$2"
    local name; name="${src##*/}" # Extract the repository name from the URL
    local fp; fp="${bd}/${name}"  # Full path
    if [[ ! -d "${fp}" ]]; then
        echo "Cloning ${name} from ${src} into ${fp}"
        git clone "${src}" "${fp}" || {
            echo "Failed to clone ${src}."
            return 1
        }
    else
        echo "${name} already exists in ${bd}. Skipping clone."
    fi
    cd "${fp}" || {
        echo "Failed to change directory to ${fp}. Please ensure it exists."
        return 1
    }
    git submodule sync
    git submodule update --init --recursive
    cd -1 || {
        echo "Failed to return to previous directory."
        return 1
    }
    return 0
}

# Function to build PyTorch from source in the specified build directory.
# Usage: build_pytorch <build_dir>
# Where <build_dir> is the directory where PyTorch will be built.
#
# - Usage: build_pytorch <build_dir>
# - Example:
#
#   ```bash
#   ; build_pytorch build-2025-07-05-203137
#   Cloning pytorch from https://github.com/pytorch/pytorch into /lus/flare/projects/datascience/foremans/projects/argonne-lcf/frameworks-standalone/build-2025-07-05-203137/pytorch
#   # ...[clipped]...
#   took: 1h:59m:39s
#   ```
build_pytorch() {
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: $0 <build_dir>"
        echo "Where <build_dir> is the directory where PyTorch will be built."
        return 1
    fi
    build_dir="$(realpath "$1")"
    pt_url="https://github.com/pytorch/pytorch"
    prepare_repo_in_build_dir "${build_dir}" "${pt_url}" || {
        echo "Failed to prepare PyTorch repository."
        return 1
    }

    echo "Navigating into ${build_dir}/pytorch/"
    cd "${build_dir}/pytorch" || return 1

    echo "Checking out release/2.8 branch..."
    git checkout release/2.8

    echo "Installing PyTorch build dependencies..."
    uv pip install --link-mode=copy cmake ninja
    uv pip install --link-mode=copy -r requirements.txt
    uv pip install --link-mode=copy mkl-static mkl-include

    echo "Making triton..."
    export USE_XPU=1 # for Intel GPU support
    make triton || return 1

    echo "Setting environment variables for PyTorch build..."
    CC=$(which gcc); export CC
    CXX=$(which g++); export CXX
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

    echo "Checking compilers:"
    echo "Using gcc from: $(which -a gcc)"
    echo "Using g++ from: $(which -a g++)"

    echo "Building PyTorch (this may take ~30 minutes)..."
    python3 setup.py bdist_wheel | tee "torch-build-whl-$(tstamp).log"
    echo "Installing PyTorch wheel..."
    uv pip install --link-mode=copy dist/*.whl
    cd -1 || return 1
}

# Function to install optional PyTorch libraries
install_optional_pytorch_libs() {
    echo "Installing torchvision and torchaudio with no dependencies for XPU..."
    uv pip install --link-mode=copy torchvision torchaudio --no-deps --index-url https://download.pytorch.org/whl/xpu
    echo "Installing torchdata with no dependencies..."
    uv pip install --link-mode=copy torchdata --no-deps
}


# Function to build Intel Extension for PyTorch
build_ipex() {
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: $0 <build_dir>"
        echo "Where <build_dir> is the directory where Intel Extension for PyTorch will be built."
        return 1
    fi
    build_dir="$(realpath "$1")"
    ipex_url="https://github.com/intel/intel-extension-for-pytorch"
    prepare_repo_in_build_dir "${build_dir}" "${ipex_url}" || {
        echo "Failed to prepare Intel Extension for PyTorch repository."
        return 1
    }
    cd "${build_dir}/intel-extension-for-pytorch" || return 1

    echo "Checking out xpu-main branch..."
    git checkout xpu-main

    echo "Syncing and updating git submodules for Intel Extension for PyTorch..."
    git submodule sync
    git submodule update --init --recursive

    echo "Installing Intel Extension for PyTorch dependencies..."
    uv pip install --link-mode=copy -r requirements.txt
    uv pip install --link-mode=copy --upgrade pip setuptools wheel build black flake8

    echo "Building Intel Extension for PyTorch (IPEX)..."
    MAX_JOBS=48 CC=$(which gcc) CXX=$(which g++) INTELONEAPIROOT="${ONEAPI_ROOT}" python3 setup.py bdist_wheel | tee "ipex-build-whl-$(tstamp).log"
    echo "Installing Intel Extension for PyTorch wheel..."
    uv pip install --link-mode=copy dist/*.whl
    cd -1 || return 1
}

# Function to build torch-ccl
build_torch_ccl() {
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: $0 <build_dir>"
        echo "Where <build_dir> is the directory where torch-ccl will be built."
        return 1
    fi
    build_dir="$(realpath "$1")"
    ccl_url="https://github.com/intel/oneccl-bindings-for-pytorch"
    prepare_repo_in_build_dir "${build_dir}" "${ccl_url}" || {
        echo "Failed to prepare torch-ccl repository."
        return 1
    }

    cd "${build_dir}/oneccl-bindings-for-pytorch" || return 1

    echo "Checking out specific commit c27ded5..."
    git checkout c27ded5

    echo "Installing torch-ccl dependencies..."
    uv pip install --link-mode=copy -r requirements.txt

    echo "Building torch-ccl..."
    ONECCL_BINDINGS_FOR_PYTORCH_BACKEND=xpu INTELONEAPIROOT="${ONEAPI_ROOT}" USE_SYSTEM_ONECCL=ON COMPUTE_BACKEND=dpcpp python3 setup.py bdist_wheel | tee "torch-ccl-build-whl-$(tstamp).log"
    echo "Installing torch-ccl wheel..."
    uv pip install --link-mode=copy dist/*.whl
    cd .. || return 1
}

# Function to build mpi4py
# build_mpi4py() {
#     echo "--- Building mpi4py ---"
#     if [ ! -d "$MPI4PY_DIR" ]; then
#         echo "Cloning mpi4py/mpi4py..."
#         git clone https://github.com/mpi4py/mpi4py
#     else
#         echo "mpi4py directory already exists. Skipping clone."
#     fi
#     cd "$MPI4PY_DIR" || return 1
#     echo "Building mpi4py..."
#     CC=mpicc CXX=mpicxx python3 setup.py build |& tee build.log
#     echo "Installing mpi4py..."
#     CC=mpicc CXX=mpicxx python3 setup.py install |& tee install.log
#     cd .. || return 1
# }
#

build_mpi4py() {
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: $0 <build_dir>"
        echo "Where <build_dir> is the directory where mpi4py will be built."
        return 1
    fi
    build_dir="$(realpath "$1")"
    mpi4py_url="https://github.com/mpi4py/mpi4py"
    prepare_repo_in_build_dir "${build_dir}" "${mpi4py_url}" || {
        echo "Failed to prepare mpi4py repository."
        return 1
    }
    cd "${build_dir}/mpi4py" || return 1
    echo "Building mpi4py..."
    CC=mpicc CXX=mpicxx python3 setup.py bdist_wheel | tee "mpi4py-build-whl-$(tstamp).log"
    echo "Installing mpi4py wheel..."
    uv pip install --link-mode=copy dist/*.whl
    echo "Showing mpi4py configuration (for verification):"
    python3 -c 'import mpi4py; print(mpi4py.get_config())'
    echo "mpi4py installed successfully."
    cd -1 || return 1
}

# Function to build h5py
build_h5py() {
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: $0 <build_dir>"
        echo "Where <build_dir> is the directory where mpi4py will be built."
        return 1
    fi
    build_dir="$(realpath "$1")"
    h5py_url="https://github.com/h5py/h5py"
    prepare_repo_in_build_dir "${build_dir}" "${h5py_url}" || {
        echo "Failed to prepare h5py repository."
        return 1
    }

    echo "Installing h5py..."
    module load hdf5
    cd "${build_dir}/h5py" || return 1
    CC=mpicc CXX=mpicxx HDF5_MPI="ON" HDF5_DIR="${HDF5_ROOT}" python3 setup.py bdist_wheel | tee "h5py-build-whl-$(tstamp).log"
    echo "Showing h5cc configuration (for verification):"
    h5cc -showconfig
    cd -1 || return 1
}

# Function to build torch / ao
build_torch_ao() {
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: $0 <build_dir>"
        echo "Where <build_dir> is the directory where torch/ao will be built."
        return 1
    fi
    build_dir="$(realpath "$1")"
    ao_url="https://github.com/pytorch/ao"
    prepare_repo_in_build_dir "${build_dir}" "${ao_url}" || {
        echo "Failed to prepare torch/ao repository."
        return 1
    }

    echo "Building torch/ao..."
    cd "${build_dir}/ao" || return 1
    USE_CUDA=0 USE_XPU=1 USE_XCCL=1 python3 setup.py bdist_wheel | tee "torchao-build-whl-$(tstamp).log"
    echo "Installing torch/ao wheel..."
    uv pip install --link-mode=copy dist/*.whl
    cd -1 || return 1
}

# Function to build TorchTune and download model
build_torchtune() {
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: $0 <build_dir>"
        echo "Where <build_dir> is the directory where TorchTune will be built."
        return 1
    fi
    build_dir="$(realpath "$1")"
    torchtune_url="https://github.com/pytorch/torchtune"
    prepare_repo_in_build_dir "${build_dir}" "${torchtune_url}" || {
        echo "Failed to prepare TorchTune repository."
        return 1
    }

    echo "Installing TorchTune in editable mode..."
    cd "${build_dir}/torchtune" || return 1
    # uv pip install --link-mode=copy -e "." --require-virtualenv --verbose

    # NOTE: Replace <hf-token> with your actual Hugging Face token.
    # This step requires user interaction for the token.
    echo "Attempting to download Meta-Llama-3.1-8B-Instruct model (requires Hugging Face token)."
    echo "Please be prepared to provide your Hugging Face token when prompted, or manually run the 'tune download' command."
    echo "If you wish to skip this, comment out or remove the following 'tune download' line."
    read -p "Enter your Hugging Face token (leave blank to skip model download): " HF_TOKEN
    if [ -n "$HF_TOKEN" ]; then
        mkdir -p ~/torchtune_anl2/out_dir
        tune download meta-llama/Meta-Llama-3.1-8B-Instruct --output-dir ~/torchtune_anl2/out_dir --ignore-patterns "original/consolidated.00.pth" --hf-token "$HF_TOKEN"
    else
        echo "Hugging Face token not provided. Skipping model download."
    fi
    cd -1 || return 1
}

# Function to verify installation
verify_installation() {
    echo "--- Verifying Installation ---"
    echo "Running Python script to verify PyTorch and Intel Extension for PyTorch installation..."
    python3 -c 'import torch; print(torch.__file__); print(*torch.__config__.show().split("\n"), sep="\n") ; print(f"{torch.__version__=}"); print(f"{torch.xpu.is_available()=}"); print(f"{torch.xpu.device_count()=}") ; import torch.distributed; print(f"{torch.distributed.is_xccl_available()=}"); import torch; import intel_extension_for_pytorch as ipex; print(f"{torch.__version__=}"); print(f"{ipex.__version__=}"); import oneccl_bindings_for_pytorch as oneccl_bpt; print(f"{oneccl_bpt.__version__=}") ; [print(f"[{i}]: {torch.xpu.get_device_properties(i)}") for i in range(torch.xpu.device_count())]'
}

# --- Main Script Execution ---

main() {
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: $0 <build_dir>"
        echo "Where <build_dir> is the directory where our libraries will be built."
        return 1
    fi
    build_dir="$(realpath "$1")"
    cd "${build_dir}" || {
        echo "Failed to change directory to ${build_dir}. Please ensure it exists."
        return 1
    }
    # --- Global Variables ---
    # PYTORCH_DIR="${build_dir}/pytorch"
    # IPEX_DIR="${build_dir}/intel-extension-for-pytorch"
    # TORCH_CCL_DIR="${build_dir}/torch-ccl"
    # MPI4PY_DIR="${build_dir}/mpi4py"
    # H5PY_DIR="${build_dir}/h5py"
    # TORCH_AO_DIR="${build_dir}/ao"
    # TORCHTUNE_DIR="${build_dir}/torchtune"

    CONDA_ENV_DIR="${HOME:-/tmp/}/miniforge/$(date +%Y%m%d-%H%M%S)-test"
    # ~ 10 mins
    activate_or_create_conda_env "${CONDA_ENV_DIR}" || {  # ~ 10 mins
        echo "Failed to activate or create conda environment. Please check the output for details."
        return 1
    }

    # ~ 2 hrs
    build_pytorch "${build_dir}" || {  # ~ 2 hours
        echo "Failed to build PyTorch. Please check the output for details."
        return 1
    }

    # < 1 min
    install_optional_pytorch_libs || {  # < 1 min (9s for my last run)
        echo "Failed to install optional PyTorch libraries. Please check the output for details."
        return 1
    }

    # [BUG] hung (?) @ 2025-07-05 @ ~ 23:20
    # [ 92%] Linking CXX shared library libxetla_gemm.so]
    # will wait and see...
    build_ipex "${build_dir}" || {
        echo "Failed to build Intel Extension for PyTorch. Please check the output for details."
        return 1
    }

    build_torch_ccl "${build_dir}" || {
        echo "Failed to build torch-ccl. Please check the output for details."
        return 1
    }

    build_mpi4py "${build_dir}" || {
        echo "Failed to build mpi4py. Please check the output for details."
        return 1
    }

    build_h5py "${build_dir}" || {
        echo "Failed to build h5py. Please check the output for details."
        return 1
    }

    build_torch_ao "${build_dir}" || {
        echo "Failed to build torch/ao. Please check the output for details."
        return 1
    }
    build_torchtune "${build_dir}" || {
        echo "Failed to build TorchTune. Please check the output for details."
        return 1
    }
    verify_installation "${build_dir}"

    echo "All build and installation steps completed successfully!"
}

# Call the main function
# main
