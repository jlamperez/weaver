#!/bin/bash

# Salir inmediatamente si un comando falla
set -e

export TORCH_CUDA_ARCH_LIST="12.0"
export CUDA_HOME=/usr/local/cuda-13.0

# Colores para la terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Weaver Environment Setup (Isaac Sim + Isaac Lab) ===${NC}"

# 1. Initialize uv
if [ ! -f "pyproject.toml" ]; then
    echo -e "${GREEN}[1/8] Initializing project with uv (pyproject.toml not found)...${NC}"
    uv init --no-workspace
else
    echo -e "${GREEN}[1/8] Project already initialized. Skipping 'uv init'...${NC}"
fi
echo -e "${GREEN}Ensuring Python 3.12...${NC}"
uv python install 3.12
uv python pin 3.12

# Clear stale lockfile to avoid Python version marker conflicts
rm -f uv.lock

# 2. Configure pyproject.toml with Python 3.12 and the NVIDIA index
echo -e "${GREEN}[2/8] Configuring pyproject.toml...${NC}"

# Replace the required python line to be strictly 3.12
# We use a more generic expression compatible with more systems (including macOS)
TEMP_FILE=$(mktemp)
sed 's/^requires-python = .*/requires-python = "==3.12.*"/' pyproject.toml > "$TEMP_FILE" && mv "$TEMP_FILE" pyproject.toml

# Clone all repos that pyproject.toml references as path sources BEFORE any uv add
echo -e "${GREEN}[3/8] Cloning external repositories...${NC}"

if [ ! -d "IsaacLab" ]; then
    echo -e "${BLUE}Cloning Isaac Lab develop...${NC}"
    git clone --branch develop https://github.com/isaac-sim/IsaacLab.git
else
    echo -e "${BLUE}IsaacLab already present. Skipping clone.${NC}"
fi

if [ ! -d "leisaac" ]; then
    echo -e "${BLUE}Cloning LeIsaac...${NC}"
    git clone https://github.com/LightwheelAI/leisaac.git
else
    echo -e "${BLUE}leisaac already present. Skipping clone.${NC}"
fi

if [ ! -d "lerobot" ]; then
    echo -e "${BLUE}Cloning LeRobot...${NC}"
    git clone https://github.com/huggingface/lerobot.git
    # Patch: remove rerun-sdk upper bound (<0.27.0) — incompatible with isaaclab-visualizers[rerun] (>=0.29.0)
    sed -i 's/"rerun-sdk>=0.24.0,<0.27.0"/"rerun-sdk>=0.24.0"/' lerobot/pyproject.toml
else
    echo -e "${BLUE}lerobot already present. Skipping clone.${NC}"
fi

# 4-6. Install everything declared in pyproject.toml (PyTorch, Isaac Sim, Isaac Lab)
# All packages are pre-configured in pyproject.toml with their sources/indexes.
# Using uv sync avoids the workspace-member detection triggered by 'uv add --editable'.
echo -e "${GREEN}[4-6/8] Installing PyTorch, Isaac Sim 6.0.0, and Isaac Lab develop...${NC}"
uv sync

# lerobot is declared in pyproject.toml as a path source (not a workspace member).
# Using uv sync instead of 'uv add --editable' avoids workspace-member detection,
# which would cause uv to resolve lerobot[all] and hit the transformers==4.57.6 conflict.
# Skipped extras with transformers>=5.4.0: pi, smolvla, molmoact2, wallx, groot,
#   multi_task_dit, sarm, robometer, topreward, xvla, eo1, hilserl, vla_jepa, peft, annotations, libero
echo -e "${GREEN}[7/8] Syncing LeRobot into environment...${NC}"
uv sync

# Verification
echo -e "${BLUE}=== Verification ===${NC}"
echo -e "${GREEN}[7/7] Running a quick import test...${NC}"

uv run python -c "import isaacsim; from isaaclab.app import AppLauncher; print('\n✅ ALL SET: Isaac Sim and Isaac Lab loaded successfully')"

echo -e "${BLUE}=====================================================================${NC}"
echo -e "To get started:"
echo -e "1. Activate the virtual environment: ${GREEN}source .venv/bin/activate${NC}"
echo -e "2. Run a task: ${GREEN}uv run python IsaacLab/scripts/...${NC}"
echo -e "${BLUE}=====================================================================${NC}"