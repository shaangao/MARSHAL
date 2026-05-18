# run /MARSHAL/scripts/simlink_resume_dir.sh before running this script
# needs to be run inside apptainer. call /MARSHAL/scripts/model_convert_apptainer.sh instead.

# RUN_PATH="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260415-190222"
RUN_PATH=/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260417-055818
# RUN_PATH=/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/20260503-013900
CKPT=checkpoint-59
OUTPUT_PATH=/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hf_models/selfplay/hanabi_selfplay/${CKPT}
mkdir -p ${OUTPUT_PATH}

# copy the original Qwen3-4B config.json
cp /net/projects2/ycleong/sg/strategy-rl/tmp/hf_cache/models--Qwen--Qwen3-4B/snapshots/1cfa9a7208912126459214e8b04321603b3df60c/config.json \
   ${RUN_PATH}/resume-${CKPT}/

# megatron to hf conversion
python /net/projects2/ycleong/sg/strategy-rl/MARSHAL/mcore_adapter/tools/convert.py \
    --checkpoint_path ${RUN_PATH}/resume-${CKPT} \
    --output_path ${OUTPUT_PATH}

# record provenance
cat > ${OUTPUT_PATH}/PROVENANCE.json <<EOF
{
  "source_run": "${RUN_PATH}",
  "source_checkpoint": "${CKPT}",
  "base_model": "Qwen/Qwen3-4B",
  "converted_at": "$(date -Iseconds)"
}
EOF

# copy generation_config.json
cp /net/projects2/ycleong/sg/strategy-rl/tmp/hf_cache/models--Qwen--Qwen3-4B/snapshots/1cfa9a7208912126459214e8b04321603b3df60c/generation_config.json \
   ${OUTPUT_PATH}/



# mv ${RUN_PATH}/actor_train-1/${CKPT}/iter_0000001/mp_rank_01 ${RUN_PATH}/actor_train-0/${CKPT}/iter_0000001/
# mv ${RUN_PATH}/actor_train-2/${CKPT}/iter_0000001/mp_rank_02 ${RUN_PATH}/actor_train-0/${CKPT}/iter_0000001/
# mv ${RUN_PATH}/actor_train-3/${CKPT}/iter_0000001/mp_rank_03 ${RUN_PATH}/actor_train-0/${CKPT}/iter_0000001/

# # copy generation_config.json
# cp /mnt/public/yuanhuining/models/Qwen3-4B/config.json \
#    ${RUN_PATH}/actor_train-0/${CKPT}/

# # megatron to hf conversion
# python mcore_adapter/tools/convert.py \
#    --checkpoint_path ${RUN_PATH}/actor_train-0/${CKPT}/ \
#    --output_path ${OUTPUT_PATH}

# # copy generation_config.json
# cp /mnt/public/yuanhuining/models/Qwen3-4B/generation_config.json \
#    ${OUTPUT_PATH}/

# # copy the original Qwen3-4B config.json
# cp /net/projects2/ycleong/sg/strategy-rl/tmp/hf_cache/models--Qwen--Qwen3-4B/snapshots/1cfa9a7208912126459214e8b04321603b3df60c/config.json \
#    ${RUN_PATH}/resume-${CKPT}/

