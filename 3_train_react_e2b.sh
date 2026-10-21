#!/usr/bin/env bash
# Smoke test for 4_train_react_e2b.sh: identical settings (see that script for why they differ from Case 1),
# but a single training step of 8 prompts x 8 rollouts, a 5-minute sandbox timeout so sandboxes pause and
# auto-resume (task_config_react_e2b_smoke.yaml), no checkpoint and no validation. NUM_WARMUP_BATCHES=0 because sessions
# prefetched for a second step would be orphaned in E2B when the job exits. Start Ray first, then run it as is.
set -euo pipefail
cd "$(dirname "$0")"
source env.sh
python3 prepare_e2b_job.py

MODEL_PATH=$MODEL_DIR/Qwen3-Coder-30B-A3B-Instruct \
TRAIN_FILE=$DATA_DIR/swe_rebench_500_seed42_oracle_ok.parquet \
TEST_FILE=$DATA_DIR/verified_100_seed42.parquet \
RUNTIME_ENV=$RUNTIME_DIR/runtime_env_e2b.yaml \
TASK_CONFIG=configs/task_config_react_e2b_smoke.yaml \
PROJECT_NAME=Uni-Agent-Qwen3-Coder-30B-react-e2b \
EXP_NAME="smoke_$(date +%m%d_%H%M)" \
NNODES=1 CONCURRENCY=256 PP=1 CP=1 \
NUM_WARMUP_BATCHES=0 MAX_RESPONSE_LENGTH=122880 \
MASK_UNFINISHED_EPISODE=True LOSS_MODE=gspo CLIP_RATIO_LOW=4e-4 CLIP_RATIO_HIGH=4e-4 ROLLOUT_IS=token \
ROUTER_REPLAY_MODE=R3 ENABLE_ROLLOUT_ROUTING_REPLAY=True LR_DECAY_STEPS=10000 TEST_FREQ=-1 \
TRAIN_PROMPT_BSZ=8 PPO_MINI_BATCH_SIZE=8 \
bash examples/quickstart/training/train_qwen3_moe.sh \
    trainer.total_training_steps=1 \
    trainer.save_freq=-1 \
    ++actor_rollout_ref.rollout.engine_kwargs.vllm.disable_custom_all_reduce=True \
    "$@"
