#!/bin/bash
set -e

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Descargando Assets para LeIsaac (Robot SO-101 + Escena) ===${NC}"

# Definir rutas (asumiendo que estamos en la raíz de weaver)
ASSETS_DIR="leisaac/assets"
ROBOTS_DIR="$ASSETS_DIR/robots"
SCENES_DIR="$ASSETS_DIR/scenes"

# Crear carpetas si no existen
mkdir -p "$ROBOTS_DIR"
mkdir -p "$SCENES_DIR"

# 1. Descargar Robot SO-101
echo -e "${GREEN}[1/2] Descargando so101_follower.usd...${NC}"
curl -L -o "$ROBOTS_DIR/so101_follower.usd" \
    "https://github.com/LightwheelAI/leisaac/releases/download/v0.1.0/so101_follower.usd"

# 2. Descargar Escena de la cocina
echo -e "${GREEN}[2/2] Descargando kitchen_with_orange.zip...${NC}"
curl -L -o "$SCENES_DIR/kitchen_with_orange.zip" \
    "https://github.com/LightwheelAI/leisaac/releases/download/v0.1.0/kitchen_with_orange.zip"

# Verificación de tamaño (evitar archivos de 0 bytes)
FILE_SIZE=$(stat -c%s "$SCENES_DIR/kitchen_with_orange.zip")
if [ "$FILE_SIZE" -le 100 ]; then
    echo -e "${RED}ERROR: La descarga falló (0 bytes o archivo corrupto).${NC}"
    exit 1
fi

# 3. Descomprimir escena
echo -e "${GREEN}Descomprimiendo archivos...${NC}"
unzip -o "$SCENES_DIR/kitchen_with_orange.zip" -d "$SCENES_DIR"

# Limpiar el zip para ahorrar espacio
rm "$SCENES_DIR/kitchen_with_orange.zip"

echo -e "${BLUE}=====================================================================${NC}"
echo -e "✅ ASSETS LISTOS"
echo -e "Robot: $ROBOTS_DIR/so101_follower.usd"
echo -e "Escena: $SCENES_DIR/kitchen_with_orange/scene.usd"
echo -e "${BLUE}=====================================================================${NC}"