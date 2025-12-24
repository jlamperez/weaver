#!/bin/bash

# Salir inmediatamente si un comando falla
set -e

# Colores para la terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Iniciando configuración del entorno Weaver (Isaac Sim + LeRobot) ===${NC}"

# 1. Inicializar uv en el directorio actual
# Se asume que este script se ejecuta desde la raíz del proyecto.
if [ ! -f "pyproject.toml" ]; then
    echo -e "${GREEN}[1/7] Inicializando proyecto con uv (pyproject.toml no encontrado)...${NC}"
    uv init --no-workspace
else
    echo -e "${GREEN}[1/7] El proyecto ya está inicializado. Saltando 'uv init'...${NC}"
fi
echo -e "${GREEN}Asegurando Python 3.11...${NC}"
uv python install 3.11
uv python pin 3.11

# 2. Configurar pyproject.toml con Python 3.11 y el índice de NVIDIA
echo -e "${GREEN}[2/7] Configurando pyproject.toml...${NC}"

# Reemplazar la línea de python requerida para que sea estrictamente 3.11
# Usamos una expresión más genérica y compatible con más sistemas (incluido macOS)
TEMP_FILE=$(mktemp)
sed 's/^requires-python = .*/requires-python = "==3.11.*"/' pyproject.toml > "$TEMP_FILE" && mv "$TEMP_FILE" pyproject.toml

# Añadir el índice de NVIDIA si no existe
if ! grep -q "pypi.nvidia.com" pyproject.toml; then
cat <<EOF >> pyproject.toml

[[tool.uv.index]]
name = "nvidia"
url = "https://pypi.nvidia.com"
explicit = true
EOF
fi

echo -e "${GREEN}Aplicando parche para pywin32 en Linux...${NC}"

# Añadir override para pywin32 para evitar que intente instalarse en Linux/macOS
if ! grep -q "override-dependencies" pyproject.toml; then
cat <<EOF >> pyproject.toml

[tool.uv]
override-dependencies = [
    "pywin32; sys_platform == 'win32'"
]
EOF
fi

# 3. Instalar Isaac Sim 5.1.0
echo -e "${GREEN}[3/7] Instalando Isaac Sim 5.1.0 (Esto puede tardar varios minutos)...${NC}"
uv add "isaacsim[all,extscache]==5.1.0" --index nvidia

# 4. Instalar Isaac Lab (Versión 2.3.0 específica para Isaac Sim 5.1.0)
echo -e "${GREEN}[4/7] Clonando e instalando Isaac Lab v2.3.0...${NC}"
if [ ! -d "IsaacLab" ]; then
    git clone --branch v2.3.0 https://github.com/isaac-sim/IsaacLab.git
fi

# Instalamos todos los componentes del núcleo
echo -e "${BLUE}Añadiendo componentes de Isaac Lab al entorno...${NC}"
uv add --editable ./IsaacLab/source/isaaclab
uv add --editable ./IsaacLab/source/isaaclab_assets
uv add --editable ./IsaacLab/source/isaaclab_rl
uv add --editable ./IsaacLab/source/isaaclab_tasks
uv add --editable ./IsaacLab/source/isaaclab_mimic

# 5. Instalar LeRobot y LeIsaac
# echo -e "${GREEN}[5/7] Instalando LeRobot y el puente LeIsaac...${NC}"
# uv add lerobot

echo -e "${GREEN}[6/7] Instalando LeIsaac desde la carpeta source...${NC}"
if [ ! -d "leisaac" ]; then
    git clone https://github.com/LightwheelAI/leisaac.git
fi
uv add --editable ./leisaac/source/leisaac

# 6. Verificación final
echo -e "${BLUE}=== Verificando instalación ===${NC}"
echo -e "${GREEN}[7/7] Ejecutando prueba rápida de importación...${NC}"

uv run python -c "import isaacsim; from isaaclab.app import AppLauncher; print('\n✅ TODO LISTO: Isaac Sim e Isaac Lab cargados correctamente')"

echo -e "${BLUE}=====================================================================${NC}"
echo -e "Para empezar a trabajar:"
echo -e "1. Ya estás en la carpeta del proyecto."
echo -e "2. Activa el entorno virtual: ${GREEN}source .venv/bin/activate${NC}"
echo -e "3. Prueba un ejemplo de LeIsaac: ${GREEN}uv run python leisaac/scripts/environments/teleoperation/teleop_se3_agent.py --task LeIsaac-SO101-PickOrange-v0 --enable_cameras --teleop_device so101leader${NC}"
echo -e "${BLUE}=====================================================================${NC}"