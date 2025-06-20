#!/bin/bash
#
export http_proxy="proxy.alcf.anl.gov:3128"
export https_proxy="proxy.alcf.anl.gov:3128"

source /opt/aurora/24.347.0/spack/unified/0.9.2/install/linux-sles15-x86_64/gcc-13.3.0/miniforge3-24.3.0-0-gfganax/bin/activate
conda activate /lus/flare/projects/Aurora_deployment/datascience/software/envs/conda_envs/vLLM_pytorch_2p8_oneapi_2025p1p1_pti_0p11p0_python3p10p14

module restore
module unload mpich oneapi
module use /soft/compilers/oneapi/2025.1.1/modulefiles
module use /soft/compilers/oneapi/nope/modulefiles
module add mpich/nope/develop-git.6037a7a
module add oneapi/public/2025.1.1

export HF_HOME="/flare/datasets/model-weights"
export HF_DATASETS_CACHE="/flare/datasets/model-weights"
export HF_MODULES_CACHE="/flare/datasets/model-weights"
#export HF_TOKEN="YOUR_HF_TOKEN"
export RAY_TMPDIR="/tmp"
export TMPDIR="/tmp"

export ZE_FLAT_DEVICE_HIERARCHY=FLAT
ray stop -f
#export VLLM_HOST_IP=$(getent hosts $(hostname).hsn.cm.aurora.alcf.anl.gov | awk '{ print $1 }' | tr ' ' '\n' | sort | head -n 1)
#export tiles=12
#ray --logging-level debug start --head --verbose --node-ip-address=$VLLM_HOST_IP --port=6379 --num-cpus=64 --num-gpus=$tiles&
#
#export RAY_ADDRESS=$VLLM_HOST_IP:6379
#
export no_proxy="localhost,127.0.0.1" #Set no_proxy for the client to interact with the locally hosted model

export VLLM_HOST_IP=$(getent hosts $(hostname).hsn.cm.aurora.alcf.anl.gov | awk '{ print $1 }' | tr ' ' '\n' | sort | head -n 1)
vllm serve meta-llama/Llama-3.3-70B-Instruct --distributed-executor-backend mp --port 8000 \
    --tensor-parallel-size 8 --device xpu --dtype float16 --trust-remote-code --max-model-len 32768

#python -m vllm.entrypoints.openai.api_server --model=meta-llama/Llama-3.3-70B-Instruct --port 8000 \
#    --tensor-parallel-size 8 --device xpu --dtype float16 --trust-remote-code --max-model-len 32768


#python -m vllm.entrypoints.openai.api_server --model=meta-llama/Meta-Llama-3.1-8B --trust-remote-code --device xpu \
#    --distributed-executor-backend=mp --enforce-eager --max_model_len=1024 --pipeline-parallel-size=2 --tp=2 

