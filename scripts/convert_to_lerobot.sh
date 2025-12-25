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
LEROBOT_PYTHON_VERSION="3.11"
LEROBOT_REPO_DIR="lerobot"

# --- Valores por Defecto ---
# Busca el último archivo de demo grabado para usarlo por defecto
LATEST_DEMO=$(ls -t ./datasets/demo_*.hdf5 2>/dev/null | head -n 1)
DATASET_FILE=${LATEST_DEMO:-"./datasets/dataset.hdf5"}
REPO_ID="jlamperez/weaver-so101-pick-orange" # Cambia esto por tu repo_id de Hugging Face
TASK_DESCRIPTION="Grab orange and place into plate"
PUSH_FLAG=""

# --- Parseo de Argumentos ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dataset_file) DATASET_FILE="$2"; shift ;;
        --repo_id) REPO_ID="$2"; shift ;;
        --task-description) TASK_DESCRIPTION="$2"; shift ;;
        --push-to-hub) PUSH_FLAG="--push-to-hub" ;;
        *) echo -e "${YELLOW}Argumento desconocido: $1${NC}"; shift ;;
    esac
    shift
done

# --- Validación del Dataset de Entrada ---
if [ ! -f "$DATASET_FILE" ]; then
    echo -e "${RED}Error: El archivo de dataset no se encuentra en '$DATASET_FILE'.${NC}"
    echo -e "${YELLOW}Asegúrate de haber grabado una demo primero o especifica la ruta con --dataset_file.${NC}"
    exit 1
fi

# --- Preparación del Entorno de LeRobot ---
# Comprobar si el entorno es válido (si python existe). Si no, se recrea por completo.
if [ ! -f "$LEROBOT_VENV_DIR/bin/python" ]; then
    echo -e "${YELLOW}Creando entorno de LeRobot desde cero...${NC}"
    rm -rf "$LEROBOT_VENV_DIR"
    echo -e "${BLUE}=== Creando nuevo entorno virtual para LeRobot en '$LEROBOT_VENV_DIR' ===${NC}"
    uv venv -p "$LEROBOT_PYTHON_VERSION" "$LEROBOT_VENV_DIR"

    # Guardamos la ruta absoluta al directorio actual
    CURRENT_DIR=$(pwd)
    echo -e "${GREEN}Instalando LeRobot y h5py en el entorno '${LEROBOT_VENV_DIR}'...${NC}"
    # Para crear un entorno aislado en versiones de 'uv' que no soportan '--no-project',
    # ejecutamos la instalación desde un subshell en un directorio neutro (/).
    (cd / && uv pip install --python "$CURRENT_DIR/$LEROBOT_VENV_DIR/bin/python" lerobot h5py)
    # uv pip install git+https://github.com/huggingface/lerobot.git

    echo -e "${GREEN}✅ Entorno de LeRobot creado con éxito.${NC}"
else
    echo -e "${GREEN}El entorno de LeRobot ya existe y es válido. Saltando instalación.${NC}"
fi

# --- Ejecución de la Conversión ---
echo -e "${BLUE}=====================================================================${NC}"
echo -e "${GREEN}Iniciando la conversión a formato LeRobot...${NC}"
echo -e "  ${YELLOW}Dataset de entrada:${NC} $DATASET_FILE"
echo -e "  ${YELLOW}Repo ID (Hugging Face):${NC} $REPO_ID"
echo -e "  ${YELLOW}Tarea a extraer:${NC} $TASK_DESCRIPTION"
echo -e "${BLUE}=====================================================================${NC}"

# --- Limpieza y Ejecución ---
OUTPUT_DIR="$HOME/.cache/huggingface/lerobot/$REPO_ID"

echo -e "${YELLOW}Limpiando cualquier dataset anterior en: $OUTPUT_DIR${NC}"
rm -rf "$OUTPUT_DIR"

# Bypassing 'uv run' and calling the python interpreter from the isolated venv directly.
# This ensures the correct environment and its packages are used.

OUTPUT_DIR="$HOME/.cache/huggingface/lerobot/$REPO_ID"

"$LEROBOT_VENV_DIR/bin/python" scripts/isaaclab2lerobot.py \
    --input_path="$DATASET_FILE" \
    --repo_id="$REPO_ID" \
    --task-description="$TASK_DESCRIPTION" \
    $PUSH_FLAG

echo -e "${GREEN}✅ Conversión finalizada.${NC}"
echo -e "El dataset en formato LeRobot se ha guardado en: ${GREEN}$OUTPUT_DIR${NC}"
echo -e "Ahora puedes subirlo a Hugging Face Hub con: ${YELLOW}huggingface-cli upload $REPO_ID $OUTPUT_DIR --repo-type dataset${NC}"
echo -e "(Recuerda ejecutar este último comando desde el entorno de LeRobot: ${BLUE}source $LEROBOT_VENV_DIR/bin/activate${NC})"