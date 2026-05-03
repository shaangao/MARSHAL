#!/bin/bash
# TODO: autoresume still not working 
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/net/projects2/ycleong/sg/strategy-rl"
RESULTS_DIR="$PROJECT_ROOT/MARSHAL/results/hanabi_selfplay"
SIMLINK_SCRIPT="$SCRIPT_DIR/simlink_resume_dir.sh"
YAML_FILE="$PROJECT_ROOT/MARSHAL/examples/hanabi/agentic_val_hanabi_selfplay.yaml"
SBATCH_SCRIPT="$SCRIPT_DIR/train.sbatch"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[DRY RUN] No changes will be made."
    echo ""
fi

# --- Steps 1-3: Search run directories (newest first) for the latest complete checkpoint ---
ALL_RUNS=($(ls -1d "$RESULTS_DIR"/[0-9]*-[0-9]* 2>/dev/null | sort -r))
if [[ ${#ALL_RUNS[@]} -eq 0 ]]; then
    echo "ERROR: No run directories found in $RESULTS_DIR"
    exit 1
fi

BEST_RUN=""
BEST_STEP=""

for run_dir in "${ALL_RUNS[@]}"; do
    echo "Checking run: $run_dir"

    # Skip if no actor_train-* directories
    RANK_DIRS=("$run_dir"/actor_train-*)
    if [[ ! -d "${RANK_DIRS[0]}" ]]; then
        echo "  No actor_train-* directories, skipping..."
        continue
    fi

    # Collect checkpoint steps from actor_train-0
    CANDIDATE_STEPS=()
    for ckpt_dir in "$run_dir"/actor_train-0/checkpoint-*; do
        [[ -d "$ckpt_dir" ]] || continue
        step="${ckpt_dir##*checkpoint-}"
        CANDIDATE_STEPS+=("$step")
    done

    if [[ ${#CANDIDATE_STEPS[@]} -eq 0 ]]; then
        echo "  No checkpoints in actor_train-0, skipping..."
        continue
    fi

    # Check from highest step downward
    IFS=$'\n' SORTED_STEPS=($(printf '%s\n' "${CANDIDATE_STEPS[@]}" | sort -rn)); unset IFS

    for step in "${SORTED_STEPS[@]}"; do
        complete=true

        for rank_dir in "${RANK_DIRS[@]}"; do
            if [[ ! -d "$rank_dir/checkpoint-$step" ]]; then
                complete=false
                break
            fi
        done

        if $complete; then
            PIPELINE_CKPT="$run_dir/pipeline/checkpoint-$step/pipeline"
            if [[ ! -f "$PIPELINE_CKPT/worker_state_pipeline.json" ]]; then
                complete=false
            fi
        fi

        if $complete; then
            BEST_RUN="$run_dir"
            BEST_STEP="$step"
            break 2
        fi
    done

    echo "  No complete checkpoint found, trying older run..."
done

if [[ -z "$BEST_STEP" ]]; then
    echo "ERROR: No complete checkpoint found in any run directory under $RESULTS_DIR"
    exit 1
fi

RESUME_CKPT_PATH="$BEST_RUN/resume-checkpoint-$BEST_STEP"
echo ""
echo "Selected run: $BEST_RUN"
echo "  ${#RANK_DIRS[@]} actor_train rank directories"
echo "  Latest complete checkpoint: step $BEST_STEP"
echo "  Resume checkpoint path: $RESUME_CKPT_PATH"

if $DRY_RUN; then
    echo ""
    echo "[DRY RUN] Would update simlink_resume_dir.sh: PREV_RUN=$BEST_RUN STEP=$BEST_STEP"
    echo "[DRY RUN] Would run: bash $SIMLINK_SCRIPT"
    echo "[DRY RUN] Would set resume_from_checkpoint: \"$RESUME_CKPT_PATH\""
    echo "[DRY RUN] Would run: sbatch $SBATCH_SCRIPT"
    echo ""
    echo "Done! (dry run)"
    exit 0
fi

# --- Step 4: Update simlink_resume_dir.sh with the new PREV_RUN and STEP ---
echo ""
echo "Updating $SIMLINK_SCRIPT ..."
# comments out the current active PREV_RUN= line in the simlink script, preserving previous values
sed -i -E 's/^PREV_RUN=/# PREV_RUN=/' "$SIMLINK_SCRIPT"
# updates the STEP variable in the simlink script to the new best step
sed -i -E "s/^STEP=.*/STEP=$BEST_STEP/" "$SIMLINK_SCRIPT"

# find the last commented # PREV_RUN= line and insert a new PREV_RUN="<best_run>" line after it
LAST_COMMENT_LINE=$(grep -n '^# PREV_RUN=' "$SIMLINK_SCRIPT" | tail -1 | cut -d: -f1)
sed -i "${LAST_COMMENT_LINE}a\\PREV_RUN=\"$BEST_RUN\"" "$SIMLINK_SCRIPT"
echo "Updated simlink_resume_dir.sh: PREV_RUN=$BEST_RUN, STEP=$BEST_STEP"

# --- Step 5: Run simlink_resume_dir.sh ---
echo ""
echo "Running simlink_resume_dir.sh ..."
bash "$SIMLINK_SCRIPT"
echo "Symlink resume directory created at: $RESUME_CKPT_PATH"

# --- Step 6: Update the YAML to resume from the new checkpoint ---
echo ""
echo "Updating $YAML_FILE ..."
# comments out the current (uncommented) resume_from_checkpoint: "<...>" line in the YAML file
sed -i -E 's|^resume_from_checkpoint: ".+"|# &|' "$YAML_FILE"

# finds the last commented-out # resume_from_checkpoint: line, gets its line number, and stores it in LAST_RESUME_LINE
LAST_RESUME_LINE=$(grep -n '^# resume_from_checkpoint:' "$YAML_FILE" | tail -1 | cut -d: -f1)
# inserts a new active resume_from_checkpoint: "$RESUME_CKPT_PATH" line right after the last commented-out one
sed -i "${LAST_RESUME_LINE}a\\resume_from_checkpoint: \"$RESUME_CKPT_PATH\"" "$YAML_FILE"
echo "Updated YAML: resume_from_checkpoint: $RESUME_CKPT_PATH"

# --- Step 7: Submit the training job ---
echo ""
echo "Submitting training job ..."
sbatch "$SBATCH_SCRIPT"

echo ""
echo "Done!"
