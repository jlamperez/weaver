# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Weaver is a robotic development environment for manipulation tasks with the SO-101 robot arm. It integrates NVIDIA Isaac Sim (v6.0.0), Isaac Lab (v3.0.0), and LeIsaac for simulation-based teleoperation, data collection, and policy training via LeRobot (ACT).

The full pipeline is: **simulate/record demos → convert to LeRobot format → train ACT policy on Colab → serve policy → run inference in sim**.

## Environment & Package Management

- **Package manager**: `uv` exclusively. Python 3.12 is strictly required.
- **Run commands**: Use `uv run python ...` (no need to activate `.venv` first).
- **Two environments**:
  - `.venv` — main Weaver env (Isaac Sim + Isaac Lab + LeIsaac + LeRobot)
  - `.venv-lerobot` — isolated LeRobot env used only by `convert_to_lerobot.sh` and `run_policy_server.sh`
- **CUDA**: Requires CUDA 13.0 at `/usr/local/cuda-13.0` and `TORCH_CUDA_ARCH_LIST="12.0"` for RTX 5090. PyTorch uses the `cu128` index — cu128 is the highest CUDA version supported by LeRobot, avoiding index conflicts.

### Key pinned versions

| Package | Version | Notes |
|---|---|---|
| Python | 3.12 | strictly required |
| `isaacsim` | 6.0.0 | from NVIDIA PyPI index |
| Isaac Lab (`isaaclab-*`) | 3.0.0 | editable installs from `IsaacLab/source/` |
| LeIsaac (`leisaac`) | editable | from `leisaac/source/leisaac/` |
| LeRobot (`lerobot`) | editable (patched) | from `lerobot/`; patches: `packaging>=24.2`, `numpy>=2.0`, `huggingface-hub>=1.0,<2.0` |
| `torch` | 2.10.0+cu128 | PyTorch cu128 index |
| `torchvision` | 0.25.0+cu128 | PyTorch cu128 index |
| `torchaudio` | 2.10.0+cu128 | PyTorch cu128 index |
| `warp-lang` | 1.13.0 | pinned by isaacsim; requires shims for `omni.replicator.core` (see below) |

### Dependency override rationale

Several `override-dependencies` in `pyproject.toml` are needed due to conflicts between isaacsim, isaaclab, and lerobot:

- `huggingface-hub>=1.0.0,<2.0.0` — lerobot requires `>=1.0` but `transformers==4.57.6` (via isaaclab) pins `<1.0`
- `numpy>=2.0.0` — lerobot pins `<2.3.0` but `isaacsim-kernel==6.0.0.0` requires `==2.3.1`
- `packaging>=24.2` — lerobot pins `<26.0` but `isaacsim-core==6.0.0.0` requires `==26.0`

## Setup

```bash
bash scripts/setup_weaver.sh      # Full install: Isaac Sim, Isaac Lab, LeIsaac, LeRobot
bash scripts/download_assets.sh   # Download SO-101 robot models into leisaac/assets/
```

## Hardware Configuration (SO-101)

Default device paths (overridable via env vars):
- Leader arm: `LEADER_PORT=/dev/ttyACM0`
- Follower arm: `FOLLOWER_PORT=/dev/ttyACM1`
- Cameras: top `/dev/video4`, side `/dev/video2`, gripper `/dev/video6`

```bash
# Calibrate arms (run before first use or after reassembly)
bash scripts/calibrate_robot.sh both       # both arms
bash scripts/calibrate_robot.sh leader     # leader only
bash scripts/calibrate_robot.sh follower   # follower only

# Test real-robot teleoperation
bash scripts/test_teleoperate.sh
```

Calibration files are saved to `~/.cache/huggingface/lerobot/calibration/`.

## Data Collection Workflow

### 1. Record demonstrations in Isaac Sim

```bash
bash scripts/record_demo.sh                             # auto-names file with timestamp
bash scripts/record_demo.sh --task "Your-Task-v0" --task-description "description"
bash scripts/record_demo.sh --dataset_file ./datasets/my.hdf5 --resume
```

**Sim controls**: `B` = begin demo, `N` = mark successful + next, `R` = reset (marks unsuccessful). Only successful demos are converted.

Datasets are saved as HDF5 files in `./datasets/`.

### 2. Verify recordings

```bash
bash scripts/replay_demo.sh                             # replays latest HDF5 in Isaac Sim
bash scripts/replay_demo.sh --dataset_file ./datasets/my.hdf5
```

### 3. Convert to LeRobot format

```bash
bash scripts/convert_to_lerobot.sh --repo-id "your-hf-username/dataset-name"
```

This calls `scripts/isaaclab2lerobot.py` (targets LeRobot v0.4.2). Output goes to `~/.cache/huggingface/lerobot/<repo-id>/`.

The SO-101 feature schema is 6-DOF joint positions for both action and observation state, plus a 480×640 front camera video (AV1, 30fps).

### 4. Visualize & upload

```bash
bash scripts/visualize_lerobot_dataset.sh --repo-id "user/dataset" --episode-index 0
bash scripts/upload_dataset.sh --repo-id "user/dataset"   # tags with v3.0
```

## Policy Training & Inference

Training uses `scripts/train_ACT.ipynb`, designed to run on Google Colab with GPU. Connect VS Code to a Colab runtime via the Jupyter/Colab extensions.

### Run inference (two terminals required)

**Terminal 1** — policy server (uses `.venv`, port 8080):
```bash
bash scripts/run_policy_server.sh
bash scripts/run_policy_server.sh --host 0.0.0.0 --port 9090
```

**Terminal 2** — Isaac Sim inference client:
```bash
bash scripts/run_policy_inference.sh
bash scripts/run_policy_inference.sh --policy-repo-id "user/my-policy"
```

Default policy: `jlamperez/weaver-so101-act-pick-orange-policy`, action horizon 50, timeout 5000ms.

## Architecture

- **`leisaac/`** — LeIsaac submodule: teleoperation scripts (`teleop_se3_agent.py`), evaluation (`policy_inference.py`), and conversion utilities. Installed as editable package.
- **`IsaacLab/`** — Isaac Lab submodule (v2.3.0). All `isaaclab-*` packages are editable installs from here.
- **`lerobot/`** — LeRobot submodule (patched: `packaging>=23.0`, `rerun-sdk>=0.21.0`). Installed editable.
- **`scripts/`** — Shell orchestration scripts for every pipeline stage.
- **`datasets/`** — Local HDF5 demo recordings (gitignored).

The default task is `LeIsaac-SO101-PickOrange-v0`. New tasks are registered in the LeIsaac task registry.

## Running Teleoperation in Isaac Sim

```bash
uv run python leisaac/scripts/environments/teleoperation/teleop_se3_agent.py \
  --task LeIsaac-SO101-PickOrange-v0 \
  --enable_cameras \
  --viz kit
```

- `--enable_cameras` is required when the environment has camera sensors.
- `--viz kit` opens the GUI window. Without it the simulation runs headless.
- Click inside the Isaac Sim viewport before pressing any keys — `carb.input` requires OS focus on the Kit window.
- **B** = start control, **N** = success + next episode, **R** = reset (marks unsuccessful).

## Known Patches (IsaacLab 3.0.0-beta / Isaac Sim 6.0.0)

These are non-obvious fixes applied to this repo. If you regenerate the environment or see these errors come back, re-apply them.

### Warp 1.13.0 compatibility shims (fragile — do not survive `uv sync`)

`omni.replicator.core-1.13.4` uses APIs removed in Warp 1.13. Add these shims manually after install (or add them to `setup_weaver.sh`):

**`.venv/lib/python3.12/site-packages/warp/__init__.py`** — append at end:
```python
import types as _types
context = _types.SimpleNamespace(Kernel=Kernel, Function=Function, Module=Module)
```

**`.venv/lib/python3.12/site-packages/warp/types.py`** — append at end:
```python
from warp._src.types import array as array
from warp._src.types import warp_type_to_np_dtype as warp_type_to_np_dtype
from warp._src.types import np_dtype_to_warp_type as np_dtype_to_warp_type
```

### API changes from IsaacLab 2.x → 3.0

| Error | Fix |
|---|---|
| `'SimulationCfg' has no attribute 'physx'` | Use `PhysxCfg` from `isaaclab_physx.physics`: `self.sim.physics = PhysxCfg(...)` in template env cfgs |
| `asset.data.<prop>` returns `ProxyArray`, not `Tensor` | Append `.torch` to every `asset.data.*` access (e.g. `robot.data.joint_pos.torch`) |
| `mdp has no attribute ActionTermCfg` | Add `from isaaclab.managers.action_manager import ActionTermCfg` in `tasks/template/mdp/__init__.py` |
| `mdp has no attribute DifferentialIKControllerCfg` | `from isaaclab.controllers import DifferentialIKControllerCfg` in `devices/action_process.py` |
| `No module named 'isaacsim.core.utils'` | Move import inside function body; use `omni.usd.get_context().get_stage()` instead of `prim_utils` |
| `Failed to open layer scene.usd` (assets not found) | `constant.py` uses file-relative path via `Path(__file__).resolve().parents[4] / "assets"` instead of git root detection |
| `write_joint_effort_limit_to_sim` shape mismatch | `limits=new_limits.unsqueeze(1), joint_ids=[5]` in `env_utils.py` |
| Kit extension resolution failure | 3 extensions marked `optional = true` in `IsaacLab/apps/isaaclab.python.kit`: `isaacsim.core.experimental.primdata`, `isaacsim.sensors.experimental.rtx`, `isaacsim.util.debug_draw` |
