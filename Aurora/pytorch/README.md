# Building PyTorch 2.8 from Source on Aurora

## 🛞 Wheels

### PyTorch 2.9

- `conda` environment:

    ```bash
    /flare/datascience_collab/foremans/micromamba/envs/pt29-2025-07
    ```

- Wheels stored in:

    ```bash
    /flare/datascience_collab/software/python/pt29-2025-07/
    ├── intel_extension_for_pytorch-2.9.10+git43164b1-cp311-cp311-linux_x86_64.whl
    ├── mpi4py-4.1.1.dev0-cp311-cp311-linux_x86_64.whl
    ├── oneccl_bind_pt-2.8.0+xpu-cp311-cp311-linux_x86_64.whl
    ├── torch-2.9.0a0+git9a52782-cp311-cp311-linux_x86_64.whl
    ├── torchao-0.13.0+git0da89e47-py3-none-any.whl
    └── torchtune-0.0.0-py3-none-any.whl
    ```

### PyTorch 2.8

- `conda` environment:

    ```bash
    /flare/datascience_collab/foremans/micromamba/envs/pt28-2025-07
    ```

- Wheels stored in:

    ```bash
    /flare/datascience_collab/software/python/pt28-2025-07
    ├── intel_extension_for_pytorch-2.8.10+git973860d-cp311-cp311-linux_x86_64.whl
    ├── mpi4py-4.1.1.dev0-cp311-cp311-linux_x86_64.whl
    ├── oneccl_bind_pt-2.8.0+xpu-cp311-cp311-linux_x86_64.whl
    ├── torch-2.8.0a0+gitd1d97ca-cp311-cp311-linux_x86_64.whl
    ├── torchao-0.12.0+gitd9f8a681-py3-none-any.whl
    └── torchtune-0.0.0-py3-none-any.whl
    ```

## 📝 Summary

- [x] Tested and confirmed that each of the _individual_ build steps from here in
  [Aurora/pytorch/pt28.sh](https://github.com/argonne-lcf/frameworks-standalone/blob/25e4096ce0b5ef8b8d9428b9c90da8eb86e46bf7/Aurora/pytorch/pt28.sh#L576-L685)
  are functional and described below in
  [[👣 Running Step-by-Step for Verification]](#-running-step-by-step-for-verification)

### 👣 Running Step-by-Step for Verification

In order to verify the functionality of each of the individual build
components, it is useful to walk through each of the steps in
[main](https://github.com/argonne-lcf/frameworks-standalone/blob/25e4096ce0b5ef8b8d9428b9c90da8eb86e46bf7/Aurora/pytorch/pt28.sh#L576-L685)
one-by-one.

```bash
git clone https://github.com/argonne-lcf/frameworks-standalone
cd frameworks-standalone

NO_BUILD=1 source Aurora/pytorch/pt28.sh

NOW=$(tstamp)
BUILD_DIR="build-${NOW}"
mkdir -p "${BUILD_DIR}"

ENV_DIR="/flare/datascience/foremans/micromamba/envs/pt28-${NOW}"
activate_or_create_micromamba_env "${ENV_DIR}"

setup_modules
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

Each of these (individually) were successful
(though IPEX build took three tries 🤔),
so am now retrying as an automated build via:

```bash
git clone https://github.com/argonne-lcf/frameworks-standalone
cd frameworks-standalone
NOW=$(tstamp)
BUILD_DIR="build-${NOW}"
ENV_DIR="/flare/datascience/foremans/micromamba/envs/2025-07-pt28-test-${NOW}"
bash Aurora/pytorch/pt28.sh "${ENV_DIR}" "${BUILD_DIR}"
```

 🤷‍♂️ and will see how that goes
(though I expect it will only be as stable as the IPEX build)

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
    export "ZE_FLAT_DEVICE_HIERARCHY=FLAT"
}
setup_modules
```

## ✨ PyTorch Nightly

- Add [Aurora/pytorch/pt-nightly.sh](Aurora/pytorch/pt-nightly.sh) for:
  - Creating (or activating, if existing) a `conda` environment
  - Loading appropriate modules
    - **Building** and installing (from source, using `uv`) `.whl`s for:
      - `pytorch/`
        - `pytorch`
        - `torchvision`
        - `torchaudio`
        - `torchdata`
        - `ao`
        - `torchtune`
      - `intel/`
        - `intel-extension-for-pytorch`
        - `torch-ccl`
      - `mpi4py`/`mpi4py`
      - ~`h5py`/`h5py`~

## 🏗️ PyTorch 2.8

- Add [Aurora/pytorch/pt28.sh](Aurora/pytorch/pt28.sh) for:
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

[^mm]: Using [micromamba](https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html)

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
