"""Prepare a training job on the E2B sandbox; 3_train/4_train run this before submitting.

1. Writes the Ray runtime env: configs/runtime_env_e2b.yaml with its placeholders filled from the environment,
   saved as RUNTIME_DIR/runtime_env_e2b.yaml so the keys never land in git.
2. Kills the E2B sandboxes that earlier jobs left behind. A job that dies without stopping its sandboxes leaves them
   running until runtime_timeout, after which the lifecycle in the task config pauses them instead of killing them,
   so they would pile up on the E2B host. A training job takes all 8 GPUs of this node, so while no Ray job is
   active every sandbox tagged with the task config's metadata owner=uni-agent-train is a leftover.
"""

import os
from pathlib import Path
from string import Template

from e2b import Sandbox, SandboxQuery, SandboxState
from ray.job_submission import JobStatus, JobSubmissionClient

runtime_dir = Path(os.environ["RUNTIME_DIR"])
(runtime_dir / "wandb").mkdir(parents=True, exist_ok=True)
template = Template((Path(__file__).parent / "configs" / "runtime_env_e2b.yaml").read_text())
(runtime_dir / "runtime_env_e2b.yaml").write_text(template.substitute(os.environ))

active = [
    job.submission_id
    for job in JobSubmissionClient("http://127.0.0.1:8265").list_jobs()
    if job.status in (JobStatus.PENDING, JobStatus.RUNNING)
]
if active:
    print(f"E2B cleanup skipped, Ray jobs still active: {active}")
    raise SystemExit(0)

query = SandboxQuery(metadata={"owner": "uni-agent-train"}, state=[SandboxState.RUNNING, SandboxState.PAUSED])
paginator = Sandbox.list(query=query)
leftovers = list(paginator.next_items())
while paginator.has_next:
    leftovers += paginator.next_items()

for info in leftovers:
    Sandbox.kill(info.sandbox_id)
print(f"E2B cleanup: killed {len(leftovers)} leftover training sandboxes")
