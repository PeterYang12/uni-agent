#!/usr/bin/env bash
# Install RL-Insight and start its server stack (Prometheus, Tempo, Grafana) in the background.
set -euo pipefail
pip install rl-insight==0.3.0
rl-insight server install
rl-insight server start --detach
