#!/bin/bash

# Salir inmediatamente si un comando falla
set -e

# --- Configuración de Colores ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Valores por Defecto ---
TASK="LeIsaac-SO101-PickOrange-v0"
# Busca el último archivo de demo grabado para usarlo por defecto
LATEST_DEMO=$(ls -t ./datasets/demo_*.hdf5 2>/dev/null | head -n 1)
DATASET_FILE=${LATEST_DEMO:-"./datasets/dataset.hdf5"} # Usa un fallback si no encuentra ninguno
EXTRA_ARGS=""

# --- Parseo de Argumentos ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --task) TASK="$2"; shift ;;
        --dataset_file) DATASET_FILE="$2"; shift ;;
        *) EXTRA_ARGS="$EXTRA_ARGS $1" ;;
    esac
    shift
done

# --- Validación ---
if [ ! -f "$DATASET_FILE" ]; then
    echo -e "${RED}Error: El archivo de dataset no se encuentra en '$DATASET_FILE'.${NC}"
    echo -e "${YELLOW}Asegúrate de haber grabado una demo primero o especifica la ruta con --dataset_file.${NC}"
    exit 1
fi

# --- Ejecución ---
echo -e "${BLUE}=====================================================================${NC}"
echo -e "${GREEN}Iniciando la reproducción de la demo...${NC}"
echo -e "  ${YELLOW}Tarea:${NC} $TASK"
echo -e "  ${YELLOW}Archivo de Dataset:${NC} $DATASET_FILE"
echo -e "${BLUE}=====================================================================${NC}"

uv run python leisaac/scripts/environments/teleoperation/replay.py \
    --task="$TASK" \
    --num_envs=1 \
    --device=cpu \
    --enable_cameras \
    --dataset_file="$DATASET_FILE" \
    $EXTRA_ARGS

echo -e "${GREEN}✅ Reproducción finalizada.${NC}"