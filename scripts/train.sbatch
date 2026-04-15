#!/bin/bash
#SBATCH --job-name=marshal_hanabi_4b_32
#SBATCH --output=logs/train_%j.out
#SBATCH --error=logs/train_%j.err
#SBATCH --time=12:00:00
#SBATCH --partition=general
#SBATCH --nodes=1
# SBATCH --constraint="a100|h100"
#SBATCH --gpus-per-node=4
# SBATCH --gres=gpu:8
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem-per-cpu=16G
# SBATCH --mem=128G

# SBATCH --mail-type=ALL  # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=shangao@uchicago.edu  # mail notification for the job
#SBATCH --open-mode=append # So that outcomes are appended, not rewritten
#SBATCH --signal=SIGUSR1@90
echo $SLURM_RESTART_COUNT


# Ensure log directory exists
# run this script from the project root (/net/projects2/ycleong/sg/strategy-rl)
mkdir -p logs


# Set project root
PROJECT_ROOT="/net/projects2/ycleong/sg/strategy-rl"
CONTAINER_PATH="/net/projects2/ycleong/sg/containers/marshal_env"

cd "$PROJECT_ROOT"


echo "Starting training job on $(hostname)"
echo "Job ID: $SLURM_JOB_ID"

# Run the training script inside the container
apptainer exec --nv --writable \
    --bind "/net:/net" \
    --bind "$PROJECT_ROOT:/strategy-rl" \
    --bind "$PROJECT_ROOT/tmp:/strategy-rl/tmp" \
    --env "LD_LIBRARY_PATH=/.singularity.d/libs:$LD_LIBRARY_PATH" \
    --env "TRITON_LIBCUDA_PATH=/.singularity.d/libs/libcuda.so.1" \
    --env "PYTHONPATH=/strategy-rl/MARSHAL:$PYTHONPATH" \
    --env HF_HOME=/strategy-rl/tmp/hf_cache \
    --env HUGGINGFACE_HUB_CACHE=/strategy-rl/tmp/hf_cache \
    --env TRITON_CACHE_DIR=/strategy-rl/tmp/triton_cache \
    --env WANDB_API_KEY="$WANDB_API_KEY" \
    --env WANDB_DIR="/strategy-rl/MARSHAL/logs" \
    "$CONTAINER_PATH" \
    bash -c "cd /strategy-rl/MARSHAL && bash examples/hanabi/run_agentic_pipeline_hanabi_selfplay.sh"

echo "Training finished"
