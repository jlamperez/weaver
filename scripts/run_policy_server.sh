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
LEROBOT_VENV_DIR=".venv"

# --- Valores por Defecto ---
HOST="127.0.0.1"
PORT="8080"

# --- Parseo de Argumentos ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --host) HOST="$2"; shift ;;
        --port) PORT="$2"; shift ;;
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

# --- Ejecución ---
echo -e "${BLUE}=====================================================================${NC}"
echo -e "${GREEN}Iniciando el servidor de políticas de LeRobot...${NC}"
echo -e "  ${YELLOW}Host:${NC} $HOST"
echo -e "  ${YELLOW}Puerto:${NC} $PORT"
echo -e "${BLUE}=====================================================================${NC}"
echo -e "Usa ${YELLOW}Ctrl+C${NC} para detener el servidor."

"$LEROBOT_VENV_DIR/bin/python" -m lerobot.async_inference.policy_server \
    --host="$HOST" \
    --port="$PORT"

echo -e "${GREEN}✅ Servidor detenido.${NC}"
