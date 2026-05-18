# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260414-222452"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260415-190222"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260416-082536"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260417-055818"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260419-013303"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260422-104408"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260425-053524"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260426-053807"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260426-221501"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260428-233527"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260429-063637"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260429-063637"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260430-203829"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260430-203829"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260430-203829"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260501-211724"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260503-013900"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/leduc_poker_selfplay/20260503-073440"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/leduc_poker_selfplay/20260503-073440"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/leduc_poker_selfplay/20260503-073440"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/leduc_poker_selfplay/20260503-073440"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/leduc_poker_selfplay/20260506-230646"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/leduc_poker_selfplay/20260506-230646"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/leduc_poker_selfplay/20260506-230646"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/leduc_poker_selfplay/20260508-141618"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/leduc_poker_selfplay/20260508-141618"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/leduc_poker_selfplay/20260509-141301"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/leduc_poker_selfplay/20260510-021140"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/leduc_poker_selfplay/20260510-140933"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/leduc_poker_selfplay/20260510-140933"
# PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/leduc_poker_selfplay/20260510-140933"
PREV_RUN="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/leduc_poker_selfplay/20260512-195326"
STEP=129
RESUME_DIR="${PREV_RUN}/resume-checkpoint-${STEP}"

shopt -s dotglob

mkdir -p "${RESUME_DIR}"

# 1) Link actor_train-0's checkpoint contents (model weights, tokenizer, scheduler, etc.)
for f in "${PREV_RUN}/actor_train-0/checkpoint-${STEP}"/*; do
  ln -sf "$f" "${RESUME_DIR}/$(basename $f)"
done

# 2) Merge RNG states from all ranks into one directory
rm -rf "${RESUME_DIR}/rng_state"  # remove symlink (or dir) from step 1 or previous run
mkdir -p "${RESUME_DIR}/rng_state"
for rank_dir in "${PREV_RUN}"/actor_train-*/checkpoint-${STEP}/rng_state; do
  for rng_file in "${rank_dir}"/*; do
    ln -sf "$rng_file" "${RESUME_DIR}/rng_state/$(basename $rng_file)"
  done
done

# 3) Merge distributed optimizer shards from all ranks
rm -rf "${RESUME_DIR}/iter_0000001"  # remove symlink (or dir) from step 1 or previous run
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