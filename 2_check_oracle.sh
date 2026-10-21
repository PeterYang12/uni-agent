#!/bin/bash
# Run uni-agent's oracle check on the 20-task Verified pilot (expect 20/20).
# Needs the variables listed in env.sh exported.
set -eu
cd "$(dirname "$0")"
source env.sh
# On this 384-CPU AMD node, ray.init() otherwise prestarts 384 workers and waits for all of them;
# their concurrent amdsmi_init() calls exceed Ray's 60s worker registration timeout, so it hangs forever.
export RAY_prestart_worker_first_driver=0
python examples/inference/parallel_run_oracle.py \
  --data-path "$DATA_DIR/verified_20_seed42.parquet" \
  --task-config configs/verified_oracle.yaml \
  --num-workers 1 --concurrency 10 \
  --result-path "$RUNTIME_DIR/oracle_20_result.json"
