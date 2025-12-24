# Weaver

Weaver is a robotic development environment designed for advanced manipulation tasks,
integrating **NVIDIA Isaac Sim**, **Isaac Lab**, and **LeIsaac**.
This setup provides a powerful simulation platform for developing and testing robot control algorithms.

## Prerequisites

Before you begin, make sure you have the following installed on your system (**Ubuntu 24.04 is recommended**):

* An NVIDIA GPU with [compatible drivers](https://www.nvidia.com/download/index.aspx)
* [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
* [uv](https://github.com/astral-sh/uv): an extremely fast Python package installer and resolver
* `curl` and `unzip`

## Installation

Follow these steps to set up the complete development environment.

### 1. Clone the Repository

First, clone this repository to your local machine:

```bash
git clone https://github.com/jlamperez/weaver
cd weaver
```

### 2. Run the Setup Script

The main setup script automates the entire installation process. It will:

* Initialize a Python 3.11 virtual environment using `uv`
* Install **NVIDIA Isaac Sim (v5.1.0)**, which may take a significant amount of time
* Clone and install **NVIDIA Isaac Lab (v2.3.0)**
* Clone and install **LeIsaac** for teleoperation bridges

Run the script from the root of the repository:

```bash
bash scripts/setup_weaver.sh
```

### 3. Download Required Assets

LeIsaac examples require specific 3D assets (robot models and scenes). The `download_assets.sh` script will download them and place them in the correct directory (`leisaac/assets/`).

```bash
bash scripts/download_assets.sh
```

## Getting Started: Running an Example

Once the installation is complete, you can launch a teleoperation example where the **SO-101** robot picks up an orange.

### 1. Activate the Virtual Environment (Optional)

You can activate the Python environment created by `uv` to work interactively:

```bash
source .venv/bin/activate
```

> **Note:** Using `uv run` as shown below makes this step optional, as it automatically manages the environment.

### 2. Launch the Teleoperation Simulation

Run the following command to start the simulation. Isaac Sim will launch, and you will be able to control the robot.

```bash
uv run python leisaac/scripts/environments/teleoperation/teleop_se3_agent.py \
  --task LeIsaac-SO101-PickOrange-v0 \
  --enable_cameras \
  --teleop_device so101leader
```


A quick look at the SO-101 robot being controlled via a teleoperation device to pick up an orange.

[![Weaver Teleop Demo](https://img.youtube.com/vi/1oPJk7aoVN0/hqdefault.jpg)](https://www.youtube.com/watch?v=1oPJk7aoVN0)

**Arguments explained:**

* `--task`: Specifies the task to execute
* `--enable_cameras`: Enables the robot camera views in the simulation
* `--teleop_device`: Defines the input device for control. In this case, `so101leader` refers to the physical teleoperation device
