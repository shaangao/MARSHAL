#!/bin/bash
set +x
ulimit -u $(ulimit -Hu)
ray stop

# ===== debug ==== #
echo "=== ulimit ==="
ulimit -a
echo ""
echo "=== Max user processes (ulimit -u) ==="
ulimit -u
echo ""
echo "=== cgroup PID limit ==="
cat /sys/fs/cgroup/pids/slurm/*/pids.max 2>/dev/null || cat /sys/fs/cgroup/pids.max 2>/dev/null || echo "No cgroup pids limit found"
echo ""
echo "=== System-wide thread max ==="
cat /proc/sys/kernel/threads-max
echo ""
echo "=== System-wide PID max ==="
cat /proc/sys/kernel/pid_max
echo ""
echo "=== Current thread count for user ==="
ps -u $USER -L | wc -l
#######


CONFIG_PATH=$(basename $(dirname $0))

ROLL_PATH=${PWD}
export PYTHONPATH="$ROLL_PATH:$PYTHONPATH"

echo "CONFIG_PATH: $CONFIG_PATH"
echo "ROLL_PATH: $ROLL_PATH"

ROLL_OUTPUT_DIR="/net/projects2/ycleong/sg/strategy-rl/MARSHAL/results/hanabi_selfplay/$(date +%Y%m%d-%H%M%S)"
ROLL_LOG_DIR=$ROLL_OUTPUT_DIR/logs
ROLL_RENDER_DIR=$ROLL_OUTPUT_DIR/render
export ROLL_OUTPUT_DIR=$ROLL_OUTPUT_DIR
export ROLL_LOG_DIR=$ROLL_LOG_DIR
export ROLL_RENDER_DIR=$ROLL_RENDER_DIR
mkdir -p $ROLL_LOG_DIR $ROLL_RENDER_DIR

# ===== debug ==== #
THREAD_LOG="$ROLL_LOG_DIR/thread_counts.log"
(while true; do
  echo "$(date '+%Y-%m-%d %H:%M:%S') threads=$(ps -u $USER -L --no-headers | wc -l)" >> "$THREAD_LOG"
  sleep 2
done) &
MONITOR_PID=$!
#####

python examples/start_agentic_pipeline.py \
  --config_path $CONFIG_PATH  \
  --config_name agentic_val_hanabi_selfplay | tee $ROLL_LOG_DIR/custom_logs.log

# ===== debug ==== #
kill $MONITOR_PID 2>/dev/null
echo "=== Peak thread count ==="
awk -F'=' '{print $2}' "$THREAD_LOG" | sort -n | tail -1
echo "=== Thread count log ==="
cat "$THREAD_LOG"
#####
