# Environment variables that 2_check_oracle.sh, 3_train_react_e2b.sh and 4_train_react_e2b.sh need; export them
# (e.g. in ~/.bashrc) before running. Sourcing this file stops with a message naming the first missing one.
export E2B_API_KEY=${E2B_API_KEY:?export E2B_API_KEY first}
export E2B_API_URL=${E2B_API_URL:?export E2B_API_URL first, e.g. http://<e2b-host>:3000}
export E2B_SANDBOX_URL=${E2B_SANDBOX_URL:?export E2B_SANDBOX_URL first, e.g. http://<e2b-host>:3002}
export WANDB_API_KEY=${WANDB_API_KEY:?export WANDB_API_KEY first}
export MODEL_DIR=${MODEL_DIR:?export MODEL_DIR first: the directory holding Qwen3-Coder-30B-A3B-Instruct}
export DATA_DIR=${DATA_DIR:?export DATA_DIR first: the directory holding the parquet files}
export RUNTIME_DIR=${RUNTIME_DIR:?export RUNTIME_DIR first: where logs, checkpoints and the Ray runtime env go}
