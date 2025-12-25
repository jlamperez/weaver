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

# --- Parseo de Argumentos ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --repo-id) REPO_ID="$2"; shift ;;
        *) echo -e "${YELLOW}Argumento desconocido: $1${NC}"; exit 1 ;;
    esac
    shift
done

# --- Validación ---
if [ ! -f "$LEROBOT_VENV_DIR/bin/activate" ]; then
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

# --- Ejecución ---
echo -e "${BLUE}=====================================================================${NC}"
echo -e "${GREEN}Iniciando la subida del dataset a Hugging Face Hub...${NC}"
echo -e "  ${YELLOW}Repo ID:${NC} $REPO_ID"
echo -e "  ${YELLOW}Ruta Local:${NC} $DATASET_PATH"
echo -e "${BLUE}=====================================================================${NC}"

# Activar el entorno de LeRobot para tener acceso a huggingface-cli
source "$LEROBOT_VENV_DIR/bin/activate"

# Verificar si el usuario ha iniciado sesión
if ! huggingface-cli whoami &> /dev/null; then
    echo -e "${YELLOW}No has iniciado sesión en Hugging Face. Por favor, introduce tu token.${NC}"
    huggingface-cli login
fi

huggingface-cli upload "$REPO_ID" "$DATASET_PATH" --repo-type dataset

echo -e "${GREEN}✅ Subida de archivos completada.${NC}"

echo -e "${GREEN}Añadiendo la etiqueta de versión 'v3.0' al dataset en el Hub...${NC}"
TAG="v3.0"
PYTHON_CMD="from huggingface_hub import HfApi; HfApi().create_tag('$REPO_ID', tag='$TAG', repo_type='dataset')"
python -c "$PYTHON_CMD"

echo -e "${GREEN}✅ Proceso completado. El dataset ha sido subido y etiquetado correctamente.${NC}"