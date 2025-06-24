#!/bin/bash
set -e # Salir inmediatamente si un comando falla

PROJECT_DIR="/workspace"
USER_SSH_DIR="$HOME/.ssh"
# Ruta fija donde se espera que el usuario monte su clave SSH privada
MOUNTED_SSH_KEY_FILE="/tmp/ssh_key/id_rsa" 
FINAL_SSH_KEY_PATH="$USER_SSH_DIR/id_rsa"

echo "--- Iniciando Entrypoint para Claude Code ---"

# --- 0. Configuración SSH ---
mkdir -p "$USER_SSH_DIR"
chmod 700 "$USER_SSH_DIR"

CONFIGURED_SSH=false
SSH_METHOD=""

# Prioridad 1: Clave montada en la ruta fija
if [ -f "$MOUNTED_SSH_KEY_FILE" ]; then
    echo "Detectada clave SSH montada en: $MOUNTED_SSH_KEY_FILE"
    if [ -s "$MOUNTED_SSH_KEY_FILE" ]; then # Verificar si el archivo tiene contenido
        cp "$MOUNTED_SSH_KEY_FILE" "$FINAL_SSH_KEY_PATH"
        chmod 600 "$FINAL_SSH_KEY_PATH"
        CONFIGURED_SSH=true
        SSH_METHOD="montada"
    else
        echo "Advertencia: El archivo $MOUNTED_SSH_KEY_FILE está vacío. No se configurará SSH desde este archivo."
    fi
else
    echo "Información: No se proporcionó clave SSH montada en $MOUNTED_SSH_KEY_FILE."
    echo "Las operaciones Git que requieran autenticación SSH podrían fallar."
fi

if [ "$CONFIGURED_SSH" = true ]; then
    if [ -z "$GIT_HOST_DOMAIN" ]; then
        echo "Error: Se ha configurado una clave SSH (método: $SSH_METHOD), pero la variable GIT_HOST_DOMAIN está vacía."
        echo "GIT_HOST_DOMAIN es obligatoria para configurar known_hosts y evitar prompts manuales."
        exit 1
    fi
    echo "Añadiendo $GIT_HOST_DOMAIN a known_hosts..."
    # Limpiar known_hosts para evitar duplicados o conflictos si se relanza
    touch "$USER_SSH_DIR/known_hosts"
    ssh-keyscan -t rsa "$GIT_HOST_DOMAIN" > "$USER_SSH_DIR/known_hosts"
    chmod 644 "$USER_SSH_DIR/known_hosts"
    echo "Configuración SSH completada para $GIT_HOST_DOMAIN."
fi

# --- 1. Configurar Git Global ---
cd "$PROJECT_DIR"

# Verificar si ya existe configuración Git
EXISTING_GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
EXISTING_GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

# Configurar Git solo si se especifican variables o no existe configuración previa
if [ -n "$GIT_USER_NAME" ] && [ "$GIT_USER_NAME" != "Claude Docker User" ]; then
    echo "Configurando git user.name a: $GIT_USER_NAME"
    git config --global user.name "$GIT_USER_NAME"
elif [ -z "$EXISTING_GIT_NAME" ] && [ -n "$GIT_USER_NAME" ]; then
    echo "Usando git user.name por defecto: $GIT_USER_NAME"
    echo "⚠️  ADVERTENCIA: Usando configuración genérica. Para commits reales, especifica GIT_USER_NAME."
    git config --global user.name "$GIT_USER_NAME"
elif [ -n "$EXISTING_GIT_NAME" ]; then
    echo "Usando configuración Git existente - user.name: $EXISTING_GIT_NAME"
fi

if [ -n "$GIT_USER_EMAIL" ] && [ "$GIT_USER_EMAIL" != "claude-docker@example.com" ]; then
    echo "Configurando git user.email a: $GIT_USER_EMAIL"
    git config --global user.email "$GIT_USER_EMAIL"
elif [ -z "$EXISTING_GIT_EMAIL" ] && [ -n "$GIT_USER_EMAIL" ]; then
    echo "Usando git user.email por defecto: $GIT_USER_EMAIL"
    echo "⚠️  ADVERTENCIA: Usando configuración genérica. Para commits reales, especifica GIT_USER_EMAIL."
    git config --global user.email "$GIT_USER_EMAIL"
elif [ -n "$EXISTING_GIT_EMAIL" ]; then
    echo "Usando configuración Git existente - user.email: $EXISTING_GIT_EMAIL"
fi

# Configurar directorio de trabajo como seguro para Git
# Esto previene el error "dubious ownership" en volúmenes montados
echo "Configurando directorio de trabajo como seguro para Git..."
git config --global --add safe.directory /workspace
git config --global --add safe.directory '*'

# Configurar rama por defecto como 'main' en lugar de 'master'
git config --global init.defaultBranch main

# Advertencia final si no hay configuración Git válida
FINAL_GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
FINAL_GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
if [ -z "$FINAL_GIT_NAME" ] || [ -z "$FINAL_GIT_EMAIL" ]; then
    echo "⚠️  ADVERTENCIA: Configuración Git incompleta. Los commits fallarán sin user.name y user.email."
    echo "   Especifica GIT_USER_NAME y GIT_USER_EMAIL para operaciones de escritura."
fi

# --- 2. Preparar Workspace ---
if [ -n "$GIT_REPO_URL" ]; then
    echo "GIT_REPO_URL especificado: $GIT_REPO_URL"
    if [ "$(ls -A .)" ]; then # Verifica si el directorio actual (PROJECT_DIR) tiene contenido
        echo "Advertencia: El directorio de trabajo $PROJECT_DIR no está vacío. No se clonará el repositorio."
    else
        echo "Directorio de trabajo $PROJECT_DIR está vacío. Clonando repositorio..."
        git clone --depth 1 "$GIT_REPO_URL" . # Clonar en el directorio actual (PROJECT_DIR)
        echo "Repositorio clonado."
    fi
else
    echo "No se especificó GIT_REPO_URL."
    if [ "$(ls -A .)" ]; then
        echo "El workspace ($PROJECT_DIR) contiene archivos - usando directorio montado/existente."
    else
        echo "El workspace ($PROJECT_DIR) está vacío - se usará como directorio de trabajo vacío."
    fi
fi

# --- 3. Determinar argumentos para Claude Code (Modo YOLO) ---
CLAUDE_COMMAND_ARGS=()
if [ "$CLAUDE_YOLO_MODE" = "true" ] || [ "$CLAUDE_YOLO_MODE" = "TRUE" ]; then
    echo "Modo YOLO está ACTIVADO."
    CLAUDE_COMMAND_ARGS+=("--dangerously-skip-permissions") # Ajustar si el flag real es diferente
else
    echo "Modo YOLO está DESACTIVADO."
fi

# --- 4. Ejecutar Claude Code ---
TARGET_COMMAND_ARGS=("${CLAUDE_COMMAND_ARGS[@]}")
# Si se pasan argumentos al 'docker run ... mi-imagen [argumentos_claude]', se añaden aquí
if [ "$#" -gt 0 ]; then
    TARGET_COMMAND_ARGS+=("$@")
fi

echo "Ejecutando comando: claude ${TARGET_COMMAND_ARGS[*]}"
echo "----------------------------------------------"
# Usar 'exec' para que el proceso de claude reemplace al script bash.
exec claude "${TARGET_COMMAND_ARGS[@]}"