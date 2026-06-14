# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Weaver is a robotic development environment for manipulation tasks with the SO-101 robot arm. It integrates NVIDIA Isaac Sim (v5.1.0), Isaac Lab (v2.3.0), and LeIsaac for simulation-based teleoperation, data collection, and policy training via LeRobot (ACT).

The full pipeline is: **simulate/record demos → convert to LeRobot format → train ACT policy on Colab → serve policy → run inference in sim**.

## Environment & Package Management

- **Package manager**: `uv` exclusively. Python 3.11 is strictly required.
- **Run commands**: Use `uv run python ...` (no need to activate `.venv` first).
- **Two environments**:
  - `.venv` — main Weaver env (Isaac Sim + Isaac Lab + LeIsaac + LeRobot)
  - `.venv-lerobot` — isolated LeRobot env used only by `convert_to_lerobot.sh` and `run_policy_server.sh`
- **Local package indices** are defined in `pyproject.toml` pointing to `file:///home/jlamperez/Workspace/weaver/nvidia` and `file:///home/jlamperez/Workspace/weaver/pytorch-cu128` — these indices are from the sibling `weaver/` directory, not this one.
- **CUDA**: Requires CUDA 13.0 at `/usr/local/cuda-13.0` and `TORCH_CUDA_ARCH_LIST="12.0"` for RTX 5090.

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
