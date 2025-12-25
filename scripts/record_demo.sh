#!/bin/bash

# Salir inmediatamente si un comando falla
set -e

# --- Configuración de Colores ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Valores por Defecto ---
TASK="LeIsaac-SO101-PickOrange-v0"
PORT="/dev/ttyACM0"
# Genera un nombre de archivo único con timestamp para evitar sobrescribir
DATASET_FILE="./datasets/demo_$(date +%Y%m%d_%H%M%S).hdf5"
EXTRA_ARGS=""

# --- Parseo de Argumentos ---
# Permite personalizar el script desde la línea de comandos
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --task) TASK="$2"; shift ;;
        --port) PORT="$2"; shift ;;
        --dataset_file) DATASET_FILE="$2"; shift ;;
        --resume) EXTRA_ARGS="$EXTRA_ARGS --resume" ;;
        *) echo -e "${YELLOW}Argumento desconocido: $1. Se pasará directamente al script de Python.${NC}"; EXTRA_ARGS="$EXTRA_ARGS $1" ;;
    esac
    shift
done

# --- Preparación del Entorno ---
DATASET_DIR=$(dirname "$DATASET_FILE")
echo -e "${BLUE}Asegurando que el directorio del dataset exista: ${DATASET_DIR}${NC}"
mkdir -p "$DATASET_DIR"

# --- Ejecución ---
echo -e "${BLUE}=====================================================================${NC}"
echo -e "${GREEN}Iniciando la grabación de la demo...${NC}"
echo -e "  ${YELLOW}Tarea:${NC} $TASK"
echo -e "  ${YELLOW}Puerto:${NC} $PORT"
echo -e "  ${YELLOW}Archivo de Dataset:${NC} $DATASET_FILE"
if [[ "$EXTRA_ARGS" == *"--resume"* ]]; then
    echo -e "  ${YELLOW}Modo:${NC} Reanudando grabación en archivo existente."
fi
echo -e "${BLUE}=====================================================================${NC}"
echo -e "Controles en la ventana de simulación:"
echo -e "  - ${GREEN}B${NC}: Comenzar la demo."
echo -e "  - ${GREEN}N${NC}: Marcar la demo actual como ${GREEN}exitosa${NC} y reiniciar."
echo -e "  - ${GREEN}R${NC}: Reiniciar la demo (se marcará como ${RED}no exitosa${NC})."
echo -e "  - ${GREEN}Ctrl+C${NC} en esta terminal para detener la grabación."

uv run python leisaac/scripts/environments/teleoperation/teleop_se3_agent.py \
    --task="$TASK" \
    --teleop_device=so101leader \
    --port="$PORT" \
    --num_envs=1 \
    --device=cpu \
    --enable_cameras \
    --record \
    --dataset_file="$DATASET_FILE" \
    $EXTRA_ARGS

echo -e "${GREEN}✅ Grabación finalizada. El dataset se ha guardado en: $DATASET_FILE${NC}"
