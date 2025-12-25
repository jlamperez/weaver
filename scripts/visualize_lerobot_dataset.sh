#!/bin/bash

# Salir inmediatamente si un comando falla
set -e

# --- Configuración de Colores ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Configuración del Entorno de LeRobot ---
LEROBOT_VENV_DIR=".venv-lerobot"

# --- Valores por Defecto ---
REPO_ID="jlamperez/weaver-so101-pick-orange"
EPISODE_INDEX=0

# --- Parseo de Argumentos ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --repo-id) REPO_ID="$2"; shift ;;
        --episode-index) EPISODE_INDEX="$2"; shift ;;
        *) echo -e "${YELLOW}Argumento desconocido: $1${NC}"; exit 1 ;;
    esac
    shift
done

# --- Validación ---
if [ ! -f "$LEROBOT_VENV_DIR/bin/python" ]; then
    echo -e "${RED}Error: El entorno de LeRobot no se encuentra en '$LEROBOT_VENV_DIR'.${NC}"
    echo -e "${YELLOW}Por favor, ejecuta primero 'bash scripts/convert_to_lerobot.sh' para crearlo.${NC}"
    exit 1
fi

DATASET_PATH="$HOME/.cache/huggingface/lerobot/$REPO_ID"
if [ ! -d "$DATASET_PATH" ]; then
    echo -e "${RED}Error: El dataset para el repo-id '$REPO_ID' no se encuentra en '$DATASET_PATH'.${NC}"
    echo -e "${YELLOW}Asegúrate de haber ejecutado el script de conversión para este repo-id.${NC}"
    exit 1
fi

# --- Validación del Índice del Episodio ---
# Use a more robust method to count episodes by reading the episode metadata parquet file directly.
# This avoids the CastError that `load_dataset` can cause due to schema mismatches.
PYTHON_CMD="import pyarrow.parquet as pq; import glob; import os; f=glob.glob(os.path.join('$DATASET_PATH', 'meta', 'episodes', 'chunk-*', '*.parquet'))[0]; print(pq.read_table(f).num_rows)"
NUM_EPISODES=$("$LEROBOT_VENV_DIR/bin/python" -c "$PYTHON_CMD")
echo -e "${BLUE}Episodios encontrados en el dataset:${NC} $NUM_EPISODES"

if [ "$EPISODE_INDEX" -ge "$NUM_EPISODES" ]; then
    echo -e "${RED}Error: El índice del episodio '$EPISODE_INDEX' está fuera de rango.${NC}"
    echo -e "${YELLOW}El dataset '$REPO_ID' solo tiene $NUM_EPISODES episodios (índices del 0 al $(($NUM_EPISODES - 1))).${NC}"
    exit 1
fi

# --- Ejecución ---
echo -e "${BLUE}=====================================================================${NC}"
echo -e "${GREEN}Iniciando la visualización del dataset de LeRobot...${NC}"
echo -e "  ${YELLOW}Repo ID:${NC} $REPO_ID"
echo -e "  ${YELLOW}Índice del Episodio:${NC} $EPISODE_INDEX"
echo -e "${BLUE}=====================================================================${NC}"

# Añadimos la carpeta 'bin' del entorno de LeRobot al PATH para que pueda encontrar el ejecutable de Rerun.
# Esto soluciona el error "Failed to find Rerun Viewer executable in PATH".
PATH="$LEROBOT_VENV_DIR/bin:$PATH" "$LEROBOT_VENV_DIR/bin/lerobot-dataset-viz" \
    --repo-id "$REPO_ID" \
    --episode-index "$EPISODE_INDEX"

echo -e "${GREEN}✅ Visualización finalizada.${NC}"
