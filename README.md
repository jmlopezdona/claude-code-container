```markdown
# Ejecución Segura y Configurable de Claude Code con Docker

Este documento describe cómo construir y utilizar una imagen Docker para ejecutar Claude Code de forma segura y configurable. La solución permite trabajar con repositorios Git (públicos y privados mediante SSH), montar workspaces locales, activar el modo YOLO de Claude Code y persistir la configuración inicial de Claude Code para evitar repetirla.

## 1. Propósito

El objetivo es proporcionar un entorno aislado y reproducible para Claude Code que:
- Proteja el sistema anfitrión de operaciones potencialmente peligrosas (especialmente en modo YOLO).
- Simplifique la gestión de dependencias (Node.js, Claude Code CLI, Git, etc.).
- Facilite la configuración para interactuar con repositorios Git.
- Permita la elección entre un workspace local montado o la clonación de un repositorio Git.
- **Persista la configuración inicial de Claude Code (login, API keys, preferencias del editor) entre sesiones.**

## 2. Requisitos Previos

- **Docker:** Debes tener Docker instalado y funcionando en tu sistema.
- **Clave SSH:** Para interactuar con repositorios Git privados usando SSH es necesaria una clave SSH privada.
- **Suscricion a Claude Code o API KEY de Anthropic** Necesaria en la configuracion inicial de Claude Code
- **Directorio de Configuración en el Host:** Un directorio vacío en tu sistema anfitrión donde se guardará la configuración persistente de Claude Code. Ejemplo: `~/.claude-code-container`.

## 3. Construcción de la Imagen Docker

1. Guarda los archivos `Dockerfile` y `entrypoint.sh` (proporcionados anteriormente) en un directorio vacío.
2. Abre una terminal en ese directorio.
3. Ejecuta el siguiente comando para construir la imagen. Puedes cambiar `claude-code-container` por el nombre y etiqueta que prefieras:
   ```bash
   docker build -t claude-code-container .
   ```

## 4. Persistencia de la Configuración de Claude Code

Claude Code puede requerir una configuración inicial interactiva (login, API key, preferencias). Para evitar repetir este proceso en cada ejecución del contenedor, se recomienda persistir el directorio de configuración de Claude Code usando un volumen Docker.

Basado en análisis, Claude Code guarda su configuración en múltiples archivos dentro del directorio `/root` del contenedor, incluyendo `/root/.claude/` y `/root/.claude.json`.

**Procedimiento:**

1.  **Crea un directorio en tu sistema anfitrión** para almacenar esta configuración (si aún no lo has hecho). Este directorio debe estar vacío la primera vez o contener una configuración previa.
    ```bash
    mkdir -p ~/.claude-code-container
    ```

2.  **Primera Ejecución (Configuración Inicial):**
    Ejecuta el contenedor montando este directorio del host al directorio home del usuario no root (`/home/node`).
    ```bash
    docker run --rm -it \
        -v ~/.claude-code-container:/home/node \
        -v "/ruta/a/tu/proyecto:/workspace" \
        -e GIT_USER_NAME="Tu Nombre" \
        -e GIT_USER_EMAIL="tu@email.com" \
        claude-code-container
    ```
    - Durante esta sesión, realiza la configuración interactiva que te pida Claude Code (login, API key, etc.).
    - Los archivos de configuración resultantes (`.claude.json`, `.claude/`, `.gitconfig`, etc.) se guardarán en `~/.claude-code-container` en tu máquina host.

3.  **Ejecuciones Posteriores:**
    En todas las ejecuciones futuras, simplemente vuelve a montar el mismo directorio. Claude Code encontrará su configuración y no debería pedirla de nuevo.
    ```bash
    docker run --rm -it \
        -v ~/.claude-code-container:/home/node \
        -v "/ruta/a/tu/proyecto:/workspace" \
        -e GIT_USER_NAME="Tu Nombre" \
        -e GIT_USER_EMAIL="tu@email.com" \
        claude-code-container "Mi prompt para Claude"
    ```

**¡Importante sobre la Seguridad de la Configuración Persistente!**
El directorio `~/.claude-code-container` (o el que elijas) en tu host contendrá ahora información sensible como tus credenciales o API keys de Anthropic.
- **Protege este directorio en tu sistema anfitrión adecuadamente.**
- **No incluyas este directorio en repositorios Git** si contiene secretos. Añádelo a tu `.gitignore`.
- La imagen Docker `claude-code-container` en sí misma no contendrá estos secretos, lo cual es una buena práctica de seguridad. Los secretos residen en tu sistema de archivos local, gestionados a través del volumen.

## 5. Variables de Entorno Configurables

Puedes configurar el comportamiento del contenedor usando las siguientes variables de entorno al ejecutar `docker run -e VARIABLE=valor ...`:

- **`GIT_USER_NAME`**: Nombre de usuario para las confirmaciones de Git. Ejemplo: `"Tu Nombre"`.
- **`GIT_USER_EMAIL`**: Correo electrónico para las confirmaciones de Git. Ejemplo: `"tu@email.com"`.
- **`CLAUDE_YOLO_MODE`**: (Opcional) Establécelo en `"true"` para activar el modo YOLO de Claude Code (`--dangerously-skip-permissions`). Por defecto es `"false"` (modo seguro).
- **`GIT_REPO_URL`**: (Opcional) URL del repositorio Git a clonar si el workspace (`/workspace`) está vacío. Ejemplo: `"https://github.com/usuario/repo.git"` o `"git@github.com:usuario/repo.git"`.
- **`GIT_HOST_DOMAIN`**: (Obligatorio si se usa SSH) El dominio del servidor Git para `ssh-keyscan`. Ejemplo: `"github.com"`, `"gitlab.com"`.

## 6. Modos de Ejecución

El contenedor de Claude Code puede ejecutarse de dos maneras principales:

### 6.1. Modo Interactivo

Claude Code se inicia y espera tus comandos directamente en la terminal.

**Ejemplo (con configuración persistente):**
```bash
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -v "$(pwd)/mi_proyecto_local:/workspace" \
    -e GIT_USER_NAME="Tu Nombre" \
    -e GIT_USER_EMAIL="tu@email.com" \
    claude-code-container
```

### 6.2. Modo Autónomo (No Interactivo)

Pasas un prompt o comando directamente a Claude Code, y el contenedor se cerrará una vez que la tarea se complete.

**Ejemplo (con configuración persistente):**
```bash
docker run --rm \
    -v ~/.claude-code-container:/home/node \
    -v "$(pwd)/mi_proyecto_local:/workspace" \
    -e GIT_USER_NAME="Tu Nombre" \
    -e GIT_USER_EMAIL="tu@email.com" \
    claude-code-container "Resume el archivo README.md"
```

## 7. Casos de Uso y Comandos `docker run` Detallados

Asegúrate de incluir el montaje del volumen de configuración (`-v ~/.claude-code-container:/home/node`) en la mayoría de los comandos si deseas que la configuración se cargue.

### 7.1. Trabajar con un Workspace Local

```bash
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -v "$(pwd)/mi_proyecto_local:/workspace" \
    -e GIT_USER_NAME="Mi Nombre" \
    -e GIT_USER_EMAIL="mi@email.com" \
    claude-code-container
```
(Reemplaza `$(pwd)/mi_proyecto_local` con la ruta a tu proyecto).

### 7.2. Clonar un Repositorio Git Público

```bash
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -e GIT_REPO_URL="https://github.com/someuser/some-public-repo.git" \
    -e GIT_USER_NAME="Mi Nombre" \
    -e GIT_USER_EMAIL="mi@email.com" \
    claude-code-container "analiza la estructura del proyecto"
```

### 7.3. Clonar/Trabajar con un Repositorio Privado usando SSH

Monta tu clave SSH privada (solo lectura es una buena práctica) y especifica el `GIT_HOST_DOMAIN`.

```bash
# Asegúrate que tu clave SSH del host (ej: ~/.ssh/id_rsa_github) no tenga passphrase
# o usa una clave dedicada para esto.
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -v ~/.ssh/id_rsa_github:/tmp/ssh_key/id_rsa:ro \
    -v "$(pwd)/mi_proyecto_privado:/workspace" \
    -e GIT_HOST_DOMAIN="github.com" \
    -e GIT_USER_NAME="Mi Nombre" \
    -e GIT_USER_EMAIL="mi@email.com" \
    -e GIT_REPO_URL="git@github.com:tu_usuario/tu_repo_privado.git" \
    claude-code-container
```
**Notas sobre SSH:**
- El `entrypoint.sh` copiará la clave montada a `~/.ssh/id_rsa` dentro del contenedor y establecerá los permisos correctos.
- `GIT_HOST_DOMAIN` es crucial para añadir el host a `known_hosts`.

### 7.4. Activar Modo YOLO

Establece `CLAUDE_YOLO_MODE="true"`.

```bash
docker run --rm -it \
    -v ~/.claude-code-container:/home/node \
    -v "$(pwd)/mi_proyecto_local:/workspace" \
    -e GIT_USER_NAME="Mi Nombre" \
    -e GIT_USER_EMAIL="mi@email.com" \
    -e CLAUDE_YOLO_MODE="true" \
    claude-code-container "borra todos los archivos .log"
```
**¡Usa el modo YOLO con extrema precaución, especialmente con acceso de escritura a tus archivos!**

## 8. Notas Importantes y Consideraciones Adicionales

- **Permisos de Volumen:** La imagen utiliza un usuario no root (`node`) con UID/GID 1000, compatible con Colima en macOS. Esto permite el uso del modo YOLO de Claude Code mientras mantiene acceso R/W a volúmenes montados.
- **Seguridad de Claves SSH:**
  - Montar la clave SSH como un archivo de solo lectura (`:ro`) es más seguro.
  - Utiliza claves SSH dedicadas con los mínimos privilegios necesarios.
  - Nunca incluyas claves SSH directamente en tu `Dockerfile`.
- **Modificación del `entrypoint.sh`:** Si necesitas lógica más compleja, puedes extender el `entrypoint.sh`.
- **Stack Tecnológico:** Este Dockerfile base está pensado para tareas de documentación o proyectos que no requieren herramientas de build específicas. Para proyectos con necesidades (Python, Java, Node.js con dependencias de proyecto, etc.), deberás crear Dockerfiles especializados que partan de esta base (`FROM claude-code-container`) e instalen las herramientas y dependencias adicionales.

### Nota Importante para Usuarios de macOS con Colima y Permisos de Volumen

La imagen utiliza un usuario no root (`node`) con UID/GID 1000, que es compatible con la configuración por defecto de Colima en macOS. Esto resuelve tanto el problema de permisos de volumen como la restricción del modo YOLO de Claude Code.

**Ventajas de Usuario No Root con UID 1000:**
- ✅ Acceso completo R/W a volúmenes montados desde macOS vía Colima
- ✅ Compatibilidad con modo YOLO de Claude Code (requiere usuario no root)
- ✅ Mejor seguridad al no ejecutar como root
- ✅ Configuración persistente en `/home/node` en lugar de `/root`

**Configuración de Colima:**
Por defecto, Colima monta directorios del host con permisos UID/GID 1000, coincidiendo perfectamente con nuestro usuario `node`. No se requiere configuración adicional.

---

Este documento debería servir como una buena guía para empezar. ¡No dudes en adaptarlo y expandirlo según tus necesidades!
```