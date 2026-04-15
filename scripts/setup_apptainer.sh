# request an interactive compute node before running this script
# srun -p general -t "12:00:00" --mem "64G" --cpus-per-task 2 --gres gpu:1 --constraint a100 --pty /bin/bash
# for compiling apex:srun -p general -t "12:00:00" --mem "200G" --cpus-per-task 32 --gres gpu:1 --pty /bin/bash

#!/bin/bash
set -e

PROJECT_ROOT="/net/projects2/ycleong/sg/strategy-rl"
cd "$PROJECT_ROOT/MARSHAL"

# Configuration
# Using absolute path for the container sandbox
CONTAINER_PATH="/net/projects2/ycleong/sg/containers/marshal_env"
SOURCE_IMAGE="docker://nvcr.io/nvidia/pytorch:24.05-py3"

# 1. Build the sandbox if it doesn't exist
if [ ! -d "$CONTAINER_PATH" ]; then
    echo "Building Apptainer sandbox at $CONTAINER_PATH..."
    echo "Source: $SOURCE_IMAGE"
    # Ensure parent dir exists
    mkdir -p "$(dirname "$CONTAINER_PATH")"
    apptainer build --sandbox "$CONTAINER_PATH" "$SOURCE_IMAGE"
else
    echo "Using existing sandbox at $CONTAINER_PATH"
fi

# 1b. Ensure mount points exist in the sandbox
if [ ! -d "$CONTAINER_PATH/net" ]; then
    echo "Creating missing mount point /net in sandbox..."
    mkdir -p "$CONTAINER_PATH/net"
fi
if [ ! -d "$CONTAINER_PATH/strategy-rl" ]; then
    echo "Creating missing mount point /strategy-rl in sandbox..."
    mkdir -p "$CONTAINER_PATH/strategy-rl"
fi
if [ ! -d "$CONTAINER_PATH/strategy-rl/tmp" ]; then
    echo "Creating missing mount point /strategy-rl/tmp in sandbox..."
    mkdir -p "$CONTAINER_PATH/strategy-rl/tmp"
fi

# 2. Set up base environment (matching MARSHAL's Dockerfile.torch260.vllm)
echo "Ensuring MARSHAL system dependencies are installed inside the sandbox..."

# We use a flag file to avoid running this heavy installation every time.
# If you need to rebuild, you can delete this file or the entire container directory.
# SETUP_FLAG="$CONTAINER_PATH/.marshal_setup_done"

# if [ ! -f "$SETUP_FLAG" ]; then
#     echo "First-time setup detected! This will take a while (especially compiling Apex)."

echo "[1/8] Upgrading pip..."
apptainer exec --nv --writable "$CONTAINER_PATH" \
    bash -c "export DEBIAN_FRONTEND=noninteractive; pip install --upgrade pip setuptools wheel"

echo "[2/8] Uninstalling conflicting packages..."
apptainer exec --nv --writable "$CONTAINER_PATH" \
    bash -c "pip uninstall -y torch torchvision torch-tensorrt \
        flash_attn transformer-engine \
        cudf dask-cuda cugraph cugraph-service-server cuml raft-dask cugraph-dgl cugraph-pyg dask-cudf || true"

echo "[3/8] Installing PyTorch 2.6.0..."
apptainer exec --nv --writable "$CONTAINER_PATH" \
    bash -c "pip install torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124"

# echo "[4/8] Installing apt dependencies (openjdk, zip)..."
# apptainer exec --nv --writable "$CONTAINER_PATH" \
#     bash -c "apt-get update && apt-get install -y openjdk-11-jdk zip"

echo "[5/8] Installing OpenCV headless..."
apptainer exec --nv --writable "$CONTAINER_PATH" \
    bash -c "pip uninstall -y opencv opencv-python opencv-python-headless || true"
apptainer exec --nv --writable "$CONTAINER_PATH" \
    bash -c "rm -rf /usr/local/lib/python3.10/dist-packages/cv2/ || true"
apptainer exec --nv --writable "$CONTAINER_PATH" \
    bash -c "pip install opencv-python-headless==4.11.0.86"

echo "[6/8] Installing Flash Attention, vLLM, SGLang"
apptainer exec --nv --writable "$CONTAINER_PATH" \
    bash -c "pip install https://github.com/Dao-AILab/flash-attention/releases/download/v2.7.2.post1/flash_attn-2.7.2.post1+cu12torch2.6cxx11abiFALSE-cp310-cp310-linux_x86_64.whl"
apptainer exec --nv --writable "$CONTAINER_PATH" \
    bash -c "pip install 'cupy-cuda12x==13.5.1' 'vllm==0.8.4'"
# apptainer exec --nv --writable "$CONTAINER_PATH" \
#     bash -c "pip install 'sglang[srt,torch_memory_saver]==0.4.6.post4'"

echo "[7/8] Installing frameworks and utilities..."
apptainer exec --nv --writable "$CONTAINER_PATH" \
    bash -c "pip install --no-build-isolation 'numpy==1.26.4' 'optree>=0.13.0' 'spacy==3.7.5' 'weasel==0.4.1' transformer-engine[pytorch]==2.2.0 megatron-core==0.11.0 deepspeed==0.16.4"

echo "[8/8] Installing NVIDIA Apex from source (THIS MAY TAKE 30+ MINS)..."
apptainer exec --nv --writable "$CONTAINER_PATH" \
    bash -c "pip uninstall -y apex || true"
apptainer exec --nv --writable "$CONTAINER_PATH" \
    bash -c 'MAX_JOBS=32 NINJA_FLAGS="-j32" NVCC_APPEND_FLAGS="--threads 32" \
    pip install -v --disable-pip-version-check --no-cache-dir --no-build-isolation \
    --config-settings "--build-option=--cpp_ext --cuda_ext --parallel 32" \
    git+https://github.com/NVIDIA/apex.git@25.04'
    
#     # Touch flag file so it does not run again
#     touch "$SETUP_FLAG"
#     echo "Base environment setup completed successfully!"
# else
#     echo "System dependencies already installed (found $SETUP_FLAG). Skipping..."
# fi

# 3. Install ROLL and OpenSpiel
echo "Ensuring ROLL framework and OpenSpiel are installed..."
apptainer exec --nv --writable \
    --bind "/net:/net" \
    --bind "$PROJECT_ROOT:/strategy-rl" \
    "$CONTAINER_PATH" \
    bash -c "
    set -e
    pip install open_spiel tensorboard
    
    # if [ ! -d /strategy-rl/ROLL ]; then
    #     echo 'ROLL not found in /strategy-rl/ROLL. Cloning from GitHub...'
    #     cd /strategy-rl
    #     git clone https://github.com/alibaba/ROLL.git
    # fi
    
    # # Ensure it's installed
    # echo 'Installing ROLL dependencies...'
    # cd /strategy-rl/ROLL
    # if [ -f requirements.txt ]; then
    #     pip install -r requirements.txt
    # fi
    # pip install -e .
    "

# 4. install other dependencies
apptainer exec --nv --writable "$CONTAINER_PATH" \
    bash -c "
    set -e
    pip install -r requirements_torch260_vllm.txt
    pip install "click==8.2.1" "setuptools<70"
    "

# 5. Run the interactive shell
echo "Starting Apptainer shell..."
echo "Binding $PROJECT_ROOT -> /strategy-rl"

apptainer shell --nv --writable \
    --bind "/net:/net" \
    --bind "$PROJECT_ROOT:/strategy-rl" \
    --env "PYTHONPATH=/strategy-rl/ROLL:/strategy-rl/MARSHAL:$PYTHONPATH" \
    "$CONTAINER_PATH"

    # --env "JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" \

