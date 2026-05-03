PROJECT_ROOT="/net/projects2/ycleong/sg/strategy-rl"
CONTAINER_PATH="/net/projects2/ycleong/sg/containers/marshal_env"

apptainer exec --nv --writable \
    --bind "/net:/net" \
    --bind "$PROJECT_ROOT:/strategy-rl" \
    --env "PYTHONPATH=/strategy-rl/MARSHAL:$PYTHONPATH" \
    "$CONTAINER_PATH" \
    bash -c "cd /strategy-rl/MARSHAL && bash scripts/model_convert.sh"