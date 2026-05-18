# request compute node before running this script:
#    srun -p general -t "1:00:00" --mem "64G" --cpus-per-task 2 --gres gpu:1 --pty /bin/bash


PROJECT_ROOT="/net/projects2/ycleong/sg/strategy-rl"
CONTAINER_PATH="/net/projects2/ycleong/sg/containers/marshal_env"

apptainer exec --nv --writable \
    --bind "/net:/net" \
    --bind "$PROJECT_ROOT:/strategy-rl" \
    --bind "$PROJECT_ROOT/tmp:/strategy-rl/tmp" \
    --env "LD_LIBRARY_PATH=/.singularity.d/libs:$LD_LIBRARY_PATH" \
    --env "TRITON_LIBCUDA_PATH=/.singularity.d/libs/libcuda.so.1" \
    --env "PYTHONPATH=/strategy-rl/MARSHAL:$PYTHONPATH" \
    --env "TRITON_CACHE_DIR=/tmp/triton_cache_$(whoami)" \
    "$CONTAINER_PATH" \
    bash -c "cd /net/projects2/ycleong/sg/strategy-rl/MARSHAL && bash scripts/model_convert.sh"
