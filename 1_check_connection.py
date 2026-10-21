# Smoke test for using the self-hosted E2B (on gbt350-odcdh2-c05-1, 10.145.64.67) from another machine.
#
#   export E2B_API_KEY=...                         # same key as on the E2B host (runtime/embed/compose/reproduce.md)
#   export E2B_API_URL=http://10.145.64.67:3000
#   export E2B_SANDBOX_URL=http://10.145.64.67:3002
#   python remote_smoke.py
#
# Checks, in order: API reachable -> sandbox create -> command round trip
# (latency matters: every agent step is one round trip) -> file write/read ->
# outbound network from inside the sandbox (pip/git need it) -> a SWE template.
import os, statistics, sys, time, urllib.request
from e2b import Sandbox

SWE_TEMPLATE = "uni-agent-swebench-sweb-eval-x86_64-psf_1776_requests-1724-2c-4096mb-2ec90fa01596"


def step(name, fn):
    t = time.perf_counter()
    try:
        out = fn()
        print(f"[ OK ] {name:38s} {time.perf_counter() - t:6.2f}s  {out or ''}")
        return out
    except Exception as e:
        print(f"[FAIL] {name:38s} {type(e).__name__}: {str(e)[:200]}")
        sys.exit(1)


def main():
    for k in ("E2B_API_KEY", "E2B_API_URL", "E2B_SANDBOX_URL"):
        if not os.environ.get(k):
            sys.exit(f"missing env var {k}")
    api = os.environ["E2B_API_URL"]
    step("API /health", lambda: urllib.request.urlopen(api + "/health", timeout=5).status)

    sbx = step("create sandbox (base)", lambda: Sandbox.create("base", timeout=300))
    try:
        step("run command", lambda: sbx.commands.run("echo ok").stdout.strip())
        rtts = []
        for _ in range(20):
            t = time.perf_counter(); sbx.commands.run("true"); rtts.append((time.perf_counter() - t) * 1000)
        step("command round trip x20", lambda: f"p50 {statistics.median(rtts):.0f} ms, max {max(rtts):.0f} ms")
        step("write + read file", lambda: sbx.files.write("/tmp/x.txt", "hello") and sbx.files.read("/tmp/x.txt"))
        step("outbound network (pypi)", lambda: sbx.commands.run(
            "curl -s -o /dev/null -w '%{http_code}' https://pypi.org/simple/pip/", timeout=60).stdout)
    finally:
        sbx.kill()

    swe = step("create sandbox (SWE template)", lambda: Sandbox.create(SWE_TEMPLATE, timeout=300))
    try:
        step("SWE repo present", lambda: swe.commands.run("cd /testbed && git log -1 --oneline", user="root").stdout.strip())
    finally:
        swe.kill()
    print("\nall checks passed")


if __name__ == "__main__":
    main()
