#!/bin/bash

# Salir inmediatamente si un comando falla
set -e

export TORCH_CUDA_ARCH_LIST="12.0"
export CUDA_HOME=/usr/local/cuda-13.0

# Colores para la terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Weaver Environment Setup (Isaac Sim + LeRobot) ===${NC}"

# 1. Initialize uv
if [ ! -f "pyproject.toml" ]; then
    echo -e "${GREEN}[1/8] Initializing project with uv (pyproject.toml not found)...${NC}"
    uv init --no-workspace
else
    echo -e "${GREEN}[1/8] Project already initialized. Skipping 'uv init'...${NC}"
fi
echo -e "${GREEN}Ensuring Python 3.11...${NC}"
uv python install 3.11
uv python pin 3.11

# 2. Configure pyproject.toml with Python 3.11 and the NVIDIA index
echo -e "${GREEN}[2/8] Configuring pyproject.toml...${NC}"

# Replace the required python line to be strictly 3.11
# We use a more generic expression compatible with more systems (including macOS)
TEMP_FILE=$(mktemp)
sed 's/^requires-python = .*/requires-python = "==3.11.*"/' pyproject.toml > "$TEMP_FILE" && mv "$TEMP_FILE" pyproject.toml

# Add the NVIDIA index if it doesn't exist
if ! grep -q "pypi.nvidia.com" pyproject.toml; then
cat <<EOF >> pyproject.toml

[[tool.uv.index]]
name = "nvidia"
url = "https://pypi.nvidia.com"
explicit = true
EOF
fi

if ! grep -q "download.pytorch.org" pyproject.toml; then
cat <<EOF >> pyproject.toml

[[tool.uv.index]]
name = "pytorch-cu128"
url = "https://download.pytorch.org/whl/cu128"
explicit = true
EOF
fi

echo -e "${GREEN}Applying patch for pywin32 on Linux...${NC}"

# Add override for pywin32 to prevent installation on Linux/macOS
if ! grep -q "override-dependencies" pyproject.toml; then
cat <<EOF >> pyproject.toml

[tool.uv]
override-dependencies = [
    "pywin32; sys_platform == 'win32'",
    "packaging==23.0",
    "numpy<2.0",
    "torch==2.7.0+cu128",
    "torchvision==0.22.0+cu128",
    "rerun-sdk==0.21.0"
]
EOF
fi

echo -e "${GREEN}[3/8] Install for RTX 5090 (Torch 2.7 + NumPy 1.x)...${NC}"
uv add "torch==2.7.0+cu128" "torchvision==0.22.0+cu128" "torchaudio==2.7.0+cu128" "numpy<2.0" --index pytorch-cu128

# 4. Install Isaac Sim 5.1.0
echo -e "${GREEN}[4/8] Installing Isaac Sim 5.1.0...${NC}"
uv add "isaacsim[all,extscache]==5.1.0" --index nvidia

# 5. Install Isaac Lab
echo -e "${GREEN}[5/8] Installing Isaac Lab v2.3.0...${NC}"
if [ ! -d "IsaacLab" ]; then
    git clone --branch v2.3.0 https://github.com/isaac-sim/IsaacLab.git
fi

echo -e "${BLUE}Adding Isaac Lab components to the environment...${NC}"
uv add --editable ./IsaacLab/source/isaaclab
uv add --editable ./IsaacLab/source/isaaclab_assets
uv add --editable "./IsaacLab/source/isaaclab_rl[all]"
uv add --editable ./IsaacLab/source/isaaclab_tasks
uv add --editable ./IsaacLab/source/isaaclab_mimic

# 6. Install LeRobot (WITH DUAL PATCH)
echo -e "${GREEN}[6/8] Cloning and Patching LeRobot...${NC}"
if [ ! -d "lerobot" ]; then
    git clone https://github.com/huggingface/lerobot.git
fi

echo -e "${BLUE}Patching LeRobot dependencies (packaging and rerun-sdk)...${NC}"
# Patch 1: packaging (for Isaac Sim)
sed -i 's/packaging>=24.2/packaging>=23.0/' lerobot/pyproject.toml
# Patch 2: rerun-sdk (to allow version 0.21.0 which supports NumPy 1.x)
sed -i 's/rerun-sdk>=0.24.0,<0.27.0/rerun-sdk>=0.21.0,<0.27.0/' lerobot/pyproject.toml

echo -e "${BLUE}Installing LeRobot in editable mode...${NC}"
uv add --editable ./lerobot

# 7. Install LeIsaac
echo -e "${GREEN}[7/8] Installing LeIsaac.....${NC}"
if [ ! -d "leisaac" ]; then
    git clone https://github.com/LightwheelAI/leisaac.git
fi
uv add --editable ./leisaac/source/leisaac

# 8. Verification
echo -e "${BLUE}=== Verification ===${NC}"
echo -e "${GREEN}[8/8] Running a quick import test...${NC}"

uv run python -c "import isaacsim; from isaaclab.app import AppLauncher; print('\n✅ ALL SET: Isaac Sim and Isaac Lab loaded successfully')"

echo -e "${BLUE}=====================================================================${NC}"
echo -e "To get started:"
echo -e "1. You are already in the project folder."
echo -e "2. Activate the virtual environment: ${GREEN}source .venv/bin/activate${NC}"
echo -e "3. Try a LeIsaac example: ${GREEN}uv run python leisaac/scripts/environments/teleoperation/teleop_se3_agent.py --task LeIsaac-SO101-PickOrange-v0 --enable_cameras --teleop_device so101leader${NC}"
echo -e "${BLUE}=====================================================================${NC}"