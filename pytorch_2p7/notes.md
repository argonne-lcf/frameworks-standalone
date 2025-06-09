# Build Notes
- We are building PyTorch-2.7 (latest stable release as of Jun 9, 2025)
- There is an issue with the `triton-xpu` version. It seems `.ci/docker/ci_commit_pins/triton-xpu.txt`
does not pick out the correct commit from the wheels list at 
https://download.pytorch.org/whl/nightly/pytorch-triton-xpu/
- `.ci/docker/triton_version.txt` suggests `3.3.0` for `2.7.0` but for `2.7.1`
it is `3.3.1` and that conflicts with the commit pins file above.
