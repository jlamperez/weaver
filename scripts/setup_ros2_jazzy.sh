#!/bin/bash
set -e

# --- Configuration Variables ---
REPO_URL="https://github.com/isaac-sim/IsaacSim-ros_workspaces.git"
REPO_BRANCH="IsaacSim-5.1.0"
REPO_DIR="$(pwd)/IsaacSim-ros_workspaces"
CONTAINER_NAME="ros_ws_docker"
IMAGE_TAG="isaac_sim_ros:ubuntu_24_jazzy"
ROS_DISTRO="jazzy"
UBUNTU_VERSION="24.04"

# Terminal Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== [1/4] Repository Setup ===${NC}"
# 1. Clone the repository if it doesn't exist
if [ ! -d "$REPO_DIR" ]; then
    echo -e "${GREEN}Cloning Isaac Sim ROS Workspaces (Branch: $REPO_BRANCH)...${NC}"
    git clone -b "$REPO_BRANCH" "$REPO_URL"
else
    echo -e "${GREEN}Repository already exists at $REPO_DIR. Skipping clone.${NC}"
fi

# Enter the repository
cd "$REPO_DIR"

echo -e "${BLUE}=== [2/4] Executing NVIDIA Build Script ===${NC}"
# Check if the image already exists (so we don't rebuild it every time)
# Note: NVIDIA's script tags it exactly as isaac_sim_ros:ubuntu_24_jazzy
if [[ "$(docker images -q $IMAGE_TAG 2> /dev/null)" == "" ]]; then
    echo -e "${GREEN}Building custom ROS2 $ROS_DISTRO image for Ubuntu $UBUNTU_VERSION...${NC}"
    echo -e "${BLUE}This involves compiling ROS2 from source for Python 3.11 compatibility.${NC}"
    chmod +x build_ros.sh

    # Run NVIDIA's build script with our variables
    ./build_ros.sh -d "$ROS_DISTRO" -v "$UBUNTU_VERSION"
else
    echo -e "${GREEN}Docker image '$IMAGE_TAG' already exists. Skipping build phase.${NC}"
fi

echo -e "${BLUE}=== [3/4] Launching the ROS2 Container ===${NC}"
# Grant X11 permissions for GUI tools
xhost +local:docker > /dev/null

# Clean up any existing container with the same name
if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    echo -e "${GREEN}Cleaning up old container: $CONTAINER_NAME...${NC}"
    docker rm -f "$CONTAINER_NAME"
fi

# Define the local workspace path extracted by NVIDIA's script
# build_ros.sh puts everything in build_ws/jazzy/jazzy_ws/
LOCAL_WS_PATH="$REPO_DIR/build_ws/$ROS_DISTRO/${ROS_DISTRO}_ws"

echo -e "${GREEN}Copying FastDDS configuration to the build workspace...${NC}"
cp "$REPO_DIR/${ROS_DISTRO}_ws/fastdds.xml" "$LOCAL_WS_PATH/fastdds.xml"

echo -e "${GREEN}Starting container using $IMAGE_TAG...${NC}"
docker run -d -it \
    --name "$CONTAINER_NAME" \
    --net=host \
    --privileged \
    --env="DISPLAY=$DISPLAY" \
    --env="ROS_DOMAIN_ID=0" \
    -v "$LOCAL_WS_PATH:/${ROS_DISTRO}_ws" \
    -v "/tmp/.X11-unix:/tmp/.X11-unix" \
    "$IMAGE_TAG" sleep infinity

echo -e "${BLUE}=== [4/4] Finalizing Environment ===${NC}"
# Configure the container to source everything automatically
docker exec -it "$CONTAINER_NAME" bash -c "
    # Install Python dependencies required by the ROS2 CLI
    python3 -m pip install psutil

    # Clean up bashrc
    sed -i '/ros/d' ~/.bashrc
    sed -i '/FASTRTPS/d' ~/.bashrc

    # Set the correct paths (Everything is inside /jazzy_ws)
    echo 'source /jazzy_ws/install/setup.bash' >> ~/.bashrc
    echo 'export FASTRTPS_DEFAULT_PROFILES_FILE=/jazzy_ws/fastdds.xml' >> ~/.bashrc

    echo 'Environment variables updated.'
"

echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}✅ SETUP COMPLETED FOR $ROS_DISTRO ON UBUNTU $UBUNTU_VERSION${NC}"
echo -e "------------------------------------------------------------"
echo -e "Workspace Location (Host): $LOCAL_WS_PATH"
echo -e "Container Name: $CONTAINER_NAME"
echo -e ""
echo -e "To enter your ROS2 environment, run:"
echo -e "  ${BLUE}docker exec -it $CONTAINER_NAME bash${NC}"
echo -e "============================================================"