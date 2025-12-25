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

## Data Management Workflow

This project includes a set of scripts to manage the entire data lifecycle, from recording demonstrations in the simulator to converting them into a format ready for training with LeRobot.

### 1. Recording Demonstrations

Use the `record_demo.sh` script to launch the simulation in recording mode. It automatically assigns a unique timestamped filename to each new dataset.

```bash
# Start recording with default settings
bash scripts/record_demo.sh
```

**In the simulation window, use these keys:**
*   **`N`**: Mark the current demonstration as **successful** and start a new one.
*   **`R`**: Reset the demonstration (it will be marked as **unsuccessful**).

Only successful demos will be included during the conversion process.

**Customizing the recording:**
```bash
# Specify a different task and a human-readable description
bash scripts/record_demo.sh \
  --task "Your-Isaac-Task-v0" \
  --task-description "A clear description of the task"

# Resume recording into an existing file
bash scripts/record_demo.sh --dataset_file ./datasets/my_dataset.hdf5 --resume
```

### 2. Verifying Raw Data

You can verify the recorded HDF5 data in two ways:

*   **Replay in Isaac Sim:**
    Use `replay_demo.sh` to watch the recorded trajectories inside the simulator.
    ```bash
    # Replay the latest recorded dataset
    bash scripts/replay_demo.sh
    ```

### 3. Converting to LeRobot Format

The `convert_to_lerobot.sh` script handles the conversion from the HDF5 format to the LeRobot format, ready for training. The first time you run it, it will create a dedicated Python environment (`.venv-lerobot`) and install all necessary dependencies.

```bash
# Convert the latest HDF5 dataset
bash scripts/convert_to_lerobot.sh --repo-id "your-hf-username/your-dataset-name"
```

### 4. Visualizing the LeRobot Dataset

After conversion, use `visualize_lerobot_dataset.sh` to inspect the final dataset with LeRobot's built-in visualizer.

```bash
# Visualize the first episode (0) of the dataset
bash scripts/visualize_lerobot_dataset.sh --repo-id "your-hf-username/your-dataset-name"

# Visualize a different episode
bash scripts/visualize_lerobot_dataset.sh --repo-id "your-hf-username/your-dataset-name" --episode-index 5
```

### 5. Uploading to Hugging Face Hub

The `upload_dataset.sh` script automates the process of uploading your converted dataset to the Hugging Face Hub and tagging it with the correct version (`v3.0`).

```bash
# Upload the default dataset (jlamperez/weaver-so101-pick-orange)
bash scripts/upload_dataset.sh

# Upload a specific dataset by providing its repo-id
bash scripts/upload_dataset.sh --repo-id "your-hf-username/your-other-dataset"
```

You can activate the LeRobot environment and manually run the upload command:

```bash
source .venv-lerobot/bin/activate
huggingface-cli upload your-hf-username/your-dataset-name ~/.cache/huggingface/lerobot/your-hf-username/your-dataset-name --repo-type dataset
```

### 6. Training a Policy with LeRobot

After uploading your dataset, you can train a policy.

This project includes a train_ACT.ipynb notebook designed to be run on Google Colab
for training an Action-Chunking Transformer (ACT) policy.

#### 1. Open the Training Notebook in VSCode

Open the train_ACT.ipynb notebook located in the root of the project.

#### 2. Connect to a Google Colab Runtime

1. Ensure you have the official Jupyter and Google Colab extensions for VSCode.
2. In the top-right corner of the notebook, click on "Select Kernel".
3. Choose "Connect to a Google Colab kernel..." and follow the prompts to sign in to your Google account.
4. Select a runtime with GPU acceleration to speed up the training process.

#### 3. Run the Notebook Cells

Execute the cells in the notebook in order. The notebook is set up to:

* Install lerobot and its dependencies in the Colab environment.
* Load the dataset you previously uploaded to the Hugging Face Hub.
* Configure the training parameters and start the training job.
* Save the trained policy, which you can then download for evaluation.

### 7. Running Inference

Once you have trained a policy and uploaded it to the Hugging Face Hub (or if you want to use a pre-trained one), you can run it in the Isaac Sim simulator.

The process consists of two steps that must be run in **two separate terminals**:

#### Step 1: Launch the Policy Server

This server loads the policy model from the Hugging Face Hub and waits for inference requests from the simulator.

In your **first terminal**, run:

```bash
# Launch the server on localhost:8080
bash scripts/run_policy_server.sh
```

#### Step 2: Launch the Inference Simulation

This script starts Isaac Sim and connects to the policy server to get the actions for the robot to execute.

In your second terminal, run:

```bash
# Run inference using the default policy
bash scripts/run_policy_inference.sh

# To use a different policy, specify its repo-id
bash scripts/run_policy_inference.sh --policy-repo-id "your-hf-username/your-policy-name"
```

You will see the robot attempting to complete the task autonomously, controlled by the policy you have trained.

For the trained ACT here a video of the task.

https://github.com/user-attachments/assets/b26b598c-f3d1-45f8-9cb0-e698209a6c76