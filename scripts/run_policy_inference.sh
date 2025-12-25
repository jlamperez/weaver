#!/bin/bash

# Exit immediately if a command fails
set -e

# --- Color Setup ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Environment Setup ---
# This script uses the main Weaver environment, not the LeRobot one.
WEAVER_VENV_DIR=".venv"

# --- Default Policy Settings ---
TASK="LeIsaac-SO101-PickOrange-v0"
POLICY_TYPE="lerobot-act"
POLICY_HOST="localhost"
POLICY_PORT="8080"
POLICY_TIMEOUT_MS=5000
POLICY_ACTION_HORIZON=50
POLICY_LANGUAGE_INSTRUCTION="Pick up the orange and place it on the plate"
POLICY_REPO_ID="jlamperez/weaver-so101-act-pick-orange-policy"
DEVICE="cuda"

# --- Argument Parsing ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --task) TASK="$2"; shift ;;
        --policy-repo-id) POLICY_REPO_ID="$2"; shift ;;
        --policy-host) POLICY_HOST="$2"; shift ;;
        --policy-port) POLICY_PORT="$2"; shift ;;
        *) echo -e "${YELLOW}Unknown argument: $1${NC}"; exit 1 ;;
    esac
    shift
done

# --- Validation ---
if [ ! -d "$WEAVER_VENV_DIR" ]; then
    echo -e "${RED}Error: The main Weaver environment was not found in '$WEAVER_VENV_DIR'.${NC}"
    echo -e "${YELLOW}Please run 'bash scripts/setup_weaver.sh' first to create it.${NC}"
    exit 1
fi

# --- Execution ---
echo -e "${BLUE}=====================================================================${NC}"
echo -e "${GREEN}Starting policy inference in Isaac Sim...${NC}"
echo -e "  ${YELLOW}Task:${NC} $TASK"
echo -e "  ${YELLOW}Policy Checkpoint (Repo ID):${NC} $POLICY_REPO_ID"
echo -e "  ${YELLOW}Policy Server:${NC} $POLICY_HOST:$POLICY_PORT"
echo -e "${BLUE}=====================================================================${NC}"
echo -e "${YELLOW}IMPORTANT: Make sure the LeRobot policy server is running in another terminal.${NC}"
echo -e "You can launch it with: ${GREEN}bash scripts/run_policy_server.sh${NC}"
echo -e "Press ${YELLOW}Ctrl+C${NC} in this terminal to stop the simulation."

uv run python leisaac/scripts/evaluation/policy_inference.py \
    --task="$TASK" \
    --policy_type="$POLICY_TYPE" \
    --policy_host="$POLICY_HOST" \
    --policy_port="$POLICY_PORT" \
    --policy_timeout_ms="$POLICY_TIMEOUT_MS" \
    --policy_action_horizon="$POLICY_ACTION_HORIZON" \
    --policy_language_instruction="$POLICY_LANGUAGE_INSTRUCTION" \
    --policy_checkpoint_path="$POLICY_REPO_ID" \
    --device="$DEVICE" \
    --enable_cameras

echo -e "${GREEN}✅ Inference simulation finished.${NC}"
