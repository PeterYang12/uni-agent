#!/usr/bin/env bash
# ReAct RL for Qwen3-Coder-30B-A3B-Instruct on 8 MI350X GPUs with the self-hosted E2B sandbox.
# Follows Case 1 of docs/source/quickstart/rl-training.md; only values that differ from the defaults of
# examples/quickstart/training/train_qwen3_moe.sh are set here. Export the variables listed in env.sh, start Ray,
# then run it as is.
# Checkpoints are saved every 5 steps and only the latest 2 are kept; rerunning with the same EXP_NAME resumes
# from the latest one. As upstream, a checkpoint holds the model weights but not the optimizer state.
# Validates on the 100 Verified tasks before training and every 20 steps (Case 1 does not validate online).
#
# Where this differs from Case 1:
#   PP=1                  one node: EP=8 has to fit inside a single pipeline stage (Case 1 uses PP=2 on 64 GPUs)
#   CP=1 with TP=4        context parallel is not trusted on this ROCm stack yet; the script default TP=4 shards
#                         the dense layers instead (Case 1 uses TP=1 CP=4)
#   CONCURRENCY=256       the E2B host allows 400 sandboxes and validation shares this cap; the gap leaves room for
#                         sandboxes a killed run leaves running (up to 1 hour before lifecycle pauses them)
#   TRAIN_PROMPT_BSZ=32   32 x 8 = 256 trajectories per step (Case 1: 64 x 8); 14 steps per epoch on the 463 tasks
#   MAX_RESPONSE_LENGTH   prompt + response <= 128K keeps vLLM on its ROCm paged-attention kernel (~3x faster decode)
#   disable_custom_all_reduce=True      vLLM's custom all-reduce fails on this node ('invalid argument')
# The task config pauses a sandbox at E2B's 1-hour cap and resumes it on its next request, and caps a model turn at
# 8192 tokens; a session whose sandbox dies anyway is scored as unresolved instead of failing its GRPO group.
set -euo pipefail
cd "$(dirname "$0")"
# source env.sh
# python3 prepare_e2b_job.py

MODEL_PATH=$MODEL_DIR/Qwen3-Coder-30B-A3B-Instruct \
TRAIN_FILE=$DATA_DIR/swe_rebench_500_seed42_oracle_ok.parquet \
TEST_FILE=$DATA_DIR/verified_100_seed42.parquet \
RUNTIME_ENV=configs/runtime_env_e2b.yaml \
TASK_CONFIG=configs/task_config_react_e2b.yaml \
PROJECT_NAME=Uni-Agent-Qwen3-Coder-30B-react-e2b \
EXP_NAME=crusoe_react_e2b_24gpu \
NNODES=1 CONCURRENCY=256 PP=1 CP=1 \
TRAIN_PROMPT_BSZ=32 TEST_FREQ=20 \
MAX_RESPONSE_LENGTH=122880 \
MASK_UNFINISHED_EPISODE=True LOSS_MODE=gspo CLIP_RATIO_LOW=4e-4 CLIP_RATIO_HIGH=4e-4 ROLLOUT_IS=token \
ROUTER_REPLAY_MODE=R3 ENABLE_ROLLOUT_ROUTING_REPLAY=True LR_DECAY_STEPS=10000 \
bash examples/quickstart/training/train_qwen3_moe.sh \
    trainer.val_before_train=True \
    trainer.save_freq=5 \
    trainer.max_actor_ckpt_to_keep=2 \
    ++actor_rollout_ref.rollout.engine_kwargs.vllm.disable_custom_all_reduce=True \
    "$@"
