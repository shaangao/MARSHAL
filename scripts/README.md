# resume training from ckpt
- run `MARSHAL/scripts/simlink_resume_dir.sh` after setting the `PREV_RUN` directory and `STEP` for the desired checkpoint. This will create a folder `resume-checkpoint-XX` with checkpoint file simlinks in `PREV_RUN` directory.
- set the `resume_from_checkpoint` variable in training config yaml file (e.g., `MARSHAL/examples/hanabi/agentic_val_hanabi_selfplay.yaml`) to your desired `resume-checkpoint-XX` directory.
- submit training job `sbatch MARSHAL/scripts/train.sbatch`.
