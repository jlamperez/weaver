#!/bin/bash

# Salir inmediatamente si un comando falla
set -e

# --- Configuración de Colores ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- 1. Configuración de Rutas de Isaac Sim ---
ISAAC_PACKAGE_PATH=$(uv run python -c "import isaacsim; import os; print(os.path.dirname(isaacsim.__file__))" 2>/dev/null || echo "")

if [ -z "$ISAAC_PACKAGE_PATH" ]; then
    echo -e "${RED}Error: No se encontró el paquete isaacsim en el entorno uv.${NC}"
    exit 1
fi

# Librerías de Jazzy internas de Isaac Sim
JAZZY_LIB_PATH="$ISAAC_PACKAGE_PATH/exts/isaacsim.ros2.bridge/jazzy/lib"

# --- 2. Sincronización de Red ROS 2 (CRÍTICO) ---
export ROS_DOMAIN_ID=0
export ROS_DISTRO="jazzy"
export RMW_IMPLEMENTATION="rmw_fastrtps_cpp"

# Sincronizamos el archivo FastDDS con el que usa el Docker
# Según tu repo, el archivo se llama 'fastdds.xml'
FAST_DDS_PATH="$(pwd)/IsaacSim-ros_workspaces/jazzy_ws/fastdds.xml"

if [ -f "$FAST_DDS_PATH" ]; then
    export FASTRTPS_DEFAULT_PROFILES_FILE="$FAST_DDS_PATH"
    echo -e "${GREEN}✅ Red ROS2 sincronizada con:${NC} $FAST_DDS_PATH"
else
    echo -e "${YELLOW}⚠️ Advertencia: No se encontró fastdds.xml. La comunicación podría fallar.${NC}"
fi

# Añadimos las librerías al PATH del sistema
export LD_LIBRARY_PATH="$JAZZY_LIB_PATH:$LD_LIBRARY_PATH"

# --- 3. Valores por Defecto ---
TASK="LeIsaac-SO101-PickOrange-v0"
PORT="/dev/ttyACM0"
DATASET_FILE="./datasets/demo_$(date +%Y%m%d_%H%M%S).hdf5"
EXTRA_ARGS=""

# --- 4. Parseo de Argumentos ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --task) TASK="$2"; shift ;;
        --port) PORT="$2"; shift ;;
        --dataset_file) DATASET_FILE="$2"; shift ;;
        --resume) EXTRA_ARGS="$EXTRA_ARGS --resume" ;;
        *) EXTRA_ARGS="$EXTRA_ARGS $1" ;;
    esac
    shift
done

mkdir -p "$(dirname "$DATASET_FILE")"

echo -e "${BLUE}=====================================================================${NC}"
echo -e "${GREEN}Iniciando LeIsaac con Bridge ROS 2 sincronizado${NC}"
echo -e "  ${YELLOW}Domain ID:${NC} $ROS_DOMAIN_ID"
echo -e "  ${YELLOW}FastDDS XML:${NC} $FASTRTPS_DEFAULT_PROFILES_FILE"
echo -e "${BLUE}=====================================================================${NC}"

# --- 5. Ejecución ---
# IMPORTANTE: Eliminados comentarios entre líneas para evitar errores de sintaxis
uv run python leisaac/scripts/environments/teleoperation/teleop_se3_agent.py \
    --task="$TASK" \
    --teleop_device=so101leader \
    --port="$PORT" \
    --num_envs=1 \
    --device=cpu \
    --enable_cameras \
    # --kit_args="--ext:isaacsim.ros2.bridge" \
    $EXTRA_ARGS

echo -e "${GREEN}✅ Grabación finalizada.${NC}"