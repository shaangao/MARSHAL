PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260414-222452"
STEP=14
RESUME_DIR="${PREV_RUN}/resume-checkpoint-${STEP}"

shopt -s dotglob

mkdir -p "${RESUME_DIR}"

# 1) Link actor_train-0's checkpoint contents (model weights, tokenizer, scheduler, etc.)
for f in "${PREV_RUN}/actor_train-0/checkpoint-${STEP}"/*; do
  ln -sf "$f" "${RESUME_DIR}/$(basename $f)"
done

# 2) Merge RNG states from all ranks into one directory
rm -f "${RESUME_DIR}/rng_state"  # remove symlink from step 1
mkdir -p "${RESUME_DIR}/rng_state"
for rank_dir in "${PREV_RUN}"/actor_train-*/checkpoint-${STEP}/rng_state; do
  for rng_file in "${rank_dir}"/*; do
    ln -sf "$rng_file" "${RESUME_DIR}/rng_state/$(basename $rng_file)"
  done
done

# 3) Merge distributed optimizer shards from all ranks
rm -f "${RESUME_DIR}/iter_0000001"  # remove symlink from step 1
mkdir -p "${RESUME_DIR}/iter_0000001/dist_optimizer"
for rank_dir in "${PREV_RUN}"/actor_train-*/checkpoint-${STEP}/iter_0000001/dist_optimizer; do
  for shard in "${rank_dir}"/*; do
    ln -sf "$shard" "${RESUME_DIR}/iter_0000001/dist_optimizer/$(basename $shard)"
  done
done
# Also link mp_rank_* directories
for rank_dir in "${PREV_RUN}"/actor_train-*/checkpoint-${STEP}/iter_0000001/mp_rank_*; do
  ln -sf "$rank_dir" "${RESUME_DIR}/iter_0000001/$(basename $rank_dir)"
done

# 4) Copy pipeline state (step counter + log history)
mkdir -p "${RESUME_DIR}/pipeline"
cp "${PREV_RUN}/pipeline/checkpoint-${STEP}/pipeline/worker_state_pipeline.json" \
   "${RESUME_DIR}/pipeline/"
cp "${PREV_RUN}/pipeline/checkpoint-${STEP}/pipeline/rng_state_pipeline.pth" \
   "${RESUME_DIR}/pipeline/" 2>/dev/null || true