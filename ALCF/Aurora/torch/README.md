# Building PyTorch 2.8 from Source on Aurora

## 📝 Summary

Tested and confirmed that each of the _individual_ build steps from here in
[ALCF/Aurora/torch/install-pt2p8 @ main](https://github.com/argonne-lcf/frameworks-standalone/blob/25e4096ce0b5ef8b8d9428b9c90da8eb86e46bf7/ALCF/Aurora/torch/install-pt2p8.sh#L576-L685)
are functional.

### 👣 Running Step-by-Step for Verification

In order to verify the functionality of each of the individual build
components, it is useful to walk through each of the steps in
[main](https://github.com/argonne-lcf/frameworks-standalone/blob/25e4096ce0b5ef8b8d9428b9c90da8eb86e46bf7/ALCF/Aurora/torch/install-pt2p8.sh#L576-L685)
one-by-one.

```bash
git clone https://github.com/argonne-lcf/frameworks-standalone
cd frameworks-standalone
git checkout pt28-install
source ALCF/Aurora/torch/install-pt2p8.sh

BUILD_DIR="build-$(tstamp)"
mkdir -p "${BUILD_DIR}"

ENV_DIR=/flare/datascience/foremans/micromamba/envs/2025-07-pt28
activate_or_create_micromamba_env "${ENV_DIR}"

load_modules
build_pytorch "${BUILD_DIR}"
install_optional_pytorch_libs
build_ipex "${BUILD_DIR}"
build_torch_ccl "${BUILD_DIR}"
build_mpi4py "${BUILD_DIR}"
# [XXX: BROKEN, NO HDF5 MODULE (??)]
# build_h5py "${BUILD_DIR}"
build_torch_ao "${BUILD_DIR}"
build_torchtune "${BUILD_DIR}"
verify_installation
run_ezpz_test
```

Each of these (individually) were successful (though IPEX build took three
tries 🤔), so am now retrying as an automated build via:

```bash
git clone https://github.com/argonne-lcf/frameworks-standalone
cd frameworks-standalone
git checkout pt28-install
BUILD_DIR="build-$(tstamp)"
ENV_DIR="/flare/datascience/foremans/micromamba/envs/2025-07-pt28-test-$(tstamp)"
bash ALCF/Aurora/torch/install-pt2p8.sh "${ENV_DIR}" "${BUILD_DIR}"
```

and will see how that goes (though I expect it will only be as stable as the
IPEX build)

### ⏱️ Build Time(s)

|   &nbsp;   | took (hours) |
| :--------: | :----------: |
|  `torch`   |    ~ 2:00    |
|   `ipex`   |    ~ 1:00    |
| others[^1] |    < 0:30    |
| **total**  |    ~ 4:00    |


[^1]: Others:
    - `h5py/h5py` (broken ??)
    - `intel/torch-ccl`
    - `mpi4py/mpi4py`
    - `pytorch/ao`
    - `pytorch/torchaudio`
    - `pytorch/torchdata`
    - `pytorch/torchtune`
    - `pytorch/torchvision`


## 🏖️ Shell Environment

For both of the new PyTorch 2.7, 2.8 builds, we're using the following set of modules:

```bash
module restore
module unload oneapi mpich
module use /soft/compilers/oneapi/2025.1.3/modulefiles
module use /soft/compilers/oneapi/nope/modulefiles
module add mpich/nope/develop-git.6037a7a
module load cmake
unset CMAKE_ROOT
export A21_SDK_PTIROOT_OVERRIDE=/home/cchannui/debug5/pti-gpu-test/tools/pti-gpu/d5c2e2e
module add oneapi/public/2025.1.3
export "ZE_FLAT_DEVICE_HIERARCHY=FLAT"
```

## 🏗️ PyTorch 2.8

- Add [ALCF/Aurora/torch/install-pt2p8.sh](ALCF/Aurora/torch/install-pt2p8.sh) for:
  - Creating (or activating, if existing) a `conda` environment[^mm]
  - Loading appropriate modules
  - **Building** and installing (from source, using `uv`) `.whl`s for:
    - [PyTorch 2.8](https://github.com/pytorch/pytorch/tree/release/2.8)
      - \+ {`torchvision`,`torchaudio`,`torchdata`}
    - [Intel Extension for PyTorch](https://github.com/intel/intel-extension-for-pytorch)
    - [OneCCL Bindings for PyTorch](https://github.com/intel/torch-ccl)
    - [mpi4py/`mpi4py`](https://github.com/mpi4py/mpi4py)
    - [pytorch/`ao`](https://github.com/pytorch/ao)
    - [pytorch/`torchtune`](https://github.com/pytorch/ao)
  - Verifying installation
  - Verifying distributed training functionality

[^mm]: Using [micromamba](https://micromamba.org)

### IPEX Build Bugs

- [❌ TAKE 1]

    ```bash
    # [2025-07-05 @ 23:20] hung (?) (@ 92% > ~ 2 hr)
    #    [ 92%] Linking CXX shared library libxetla_gemm.so]
    ```

- [❌ TAKE 2]

    ```bash
    # [2025-07-06 @ 10:30:24] hung (?) (@ 97% )
    #     [ 97%] Built target intel-ext-pt-gpu-op-TripleOps
    # [2025-07-06 @ 11:01] ...[waiting]...
    # [2025-07-06 @ 13:00] job ended :(
    ```

- [✅ TAKE 3]

    ```bash
    # [✅ TAKE 3]
    # [2025-07-06 @ 18:00] Successfully built IPEX
    # took: 1h:05m:36s
    ```

## 📦 PyTorch 2.7

- Add [ALCF/Aurora/torch/install-pt2p7.sh](ALCF/Aurora/torch/install-pt2p7.sh), for:
  - Creating (or activating, if existing) a `conda` environment
  - Loading appropriate modules
  - Installing **pre-built** `.whl`s (provided by @khossain4337) for:
    - [PyTorch 2.7](https://github.com/pytorch/pytorch/tree/release/2.7)
    - [Intel Extension for PyTorch](https://github.com/intel/intel-extension-for-pytorch)
    - [OneCCL Bindings for PyTorch](https://github.com/intel/torch-ccl)
  - Verifying installation
