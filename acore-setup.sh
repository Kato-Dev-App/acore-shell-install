#!/usr/bin/env bash
# AzerothCore — Setup Script
# Clona, compila e instala AzerothCore (WoW 3.3.5a) desde el repositorio oficial.

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
R=$'\033[0;31m' G=$'\033[0;32m' Y=$'\033[1;33m'
B=$'\033[0;34m' C=$'\033[0;36m' W=$'\033[1;37m'
D=$'\033[2m' BD=$'\033[1m' NC=$'\033[0m'

# ─── Constants ────────────────────────────────────────────────────────────────
REPO_URL="https://github.com/azerothcore/azerothcore-wotlk.git"
PROPS_FILE="$HOME/.acore-setup.conf"

# ─── Helpers ──────────────────────────────────────────────────────────────────
ok()   { echo -e "  ${G}✔${NC}  $*"; }
info() { echo -e "  ${C}ℹ${NC}  $*"; }
warn() { echo -e "  ${Y}⚠${NC}  $*"; }
err()  { echo -e "  ${R}✘${NC}  $*" >&2; }
step() { echo -e "  ${B}›${NC}  $*"; }

pause() { echo ""; read -rp "  ${D}Presiona ENTER para continuar...${NC}" _; }

confirm() {
    read -rp "  ${Y}?${NC}  ${BD}${1:-¿Continuar?}${NC} ${D}[s/N]${NC} " ans
    [[ "$ans" =~ ^[sS]$ ]]
}

banner() {
    clear
    echo -e "${C}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║   AzerothCore — WoW 3.3.5a (WotLK) Setup Script    ║"
    echo "  ║   github.com/azerothcore/azerothcore-wotlk          ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

section() {
    echo ""
    echo -e "${B}${BD}  ══════════════════════════════════════════${NC}"
    echo -e "${W}${BD}    $1${NC}"
    echo -e "${B}${BD}  ══════════════════════════════════════════${NC}"
    echo ""
}

# ─── Defaults (overridden by props_load) ──────────────────────────────────────
INSTALL_DIR="$HOME/azeroth-server"
SOURCE_DIR="$HOME/azerothcore"
BUILD_DIR="$HOME/azerothcore/build"

DB_HOST="127.0.0.1"
DB_PORT="3306"
DB_USER="acore"
DB_PASS="acore"

SERVER_IP="0.0.0.0"
WORLD_PORT="8085"
AUTH_PORT="3724"

CLIENT_DIR=""

# Credenciales de administrador MySQL — solo para esta sesión, nunca se guardan
_ADMIN_USER=""
_ADMIN_PASS=""

# ─── Properties file ──────────────────────────────────────────────────────────
props_save() {
    cat > "$PROPS_FILE" <<EOF
# AzerothCore setup properties — generado automáticamente
INSTALL_DIR=$INSTALL_DIR
SOURCE_DIR=$SOURCE_DIR
BUILD_DIR=$BUILD_DIR
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_USER=$DB_USER
DB_PASS=$DB_PASS
SERVER_IP=$SERVER_IP
WORLD_PORT=$WORLD_PORT
AUTH_PORT=$AUTH_PORT
CLIENT_DIR=$CLIENT_DIR
EOF
    ok "Configuración guardada en: ${PROPS_FILE}"
}

props_load() {
    if [[ -f "$PROPS_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$PROPS_FILE"
    fi
}

props_load

# ─── 1. Rutas ─────────────────────────────────────────────────────────────────
ask_paths() {
    section "Rutas de instalación"
    echo -e "  ${D}Dejar vacío para aceptar el valor entre corchetes.${NC}"
    echo ""

    echo -e "  ${W}Directorio de instalación${NC} ${D}(binarios, configs, datos)${NC}"
    read -rp "  ${BD}[${INSTALL_DIR}]${NC} → " v; [[ -n "$v" ]] && INSTALL_DIR="$v"

    echo ""
    echo -e "  ${W}Directorio del código fuente${NC} ${D}(repositorio git)${NC}"
    read -rp "  ${BD}[${SOURCE_DIR}]${NC} → " v; [[ -n "$v" ]] && SOURCE_DIR="$v"

    BUILD_DIR="${SOURCE_DIR}/build"

    echo ""
    info "Instalación: ${BD}${INSTALL_DIR}${NC}"
    info "Fuente:      ${BD}${SOURCE_DIR}${NC}"
    info "Build:       ${BD}${BUILD_DIR}${NC}"
    echo ""

    props_save
    pause
}

# ─── 2. MySQL / Servidor ──────────────────────────────────────────────────────
ask_db_config() {
    section "Configuración MySQL y Servidor"
    echo -e "  ${D}Dejar vacío para aceptar el valor entre corchetes.${NC}"
    echo ""

    echo -e "  ${W}─── Base de datos MySQL ───────────────────────────${NC}"
    echo ""

    echo -e "  ${W}Host MySQL${NC}"
    read -rp "  ${BD}[${DB_HOST}]${NC} → " v; [[ -n "$v" ]] && DB_HOST="$v"

    echo ""
    echo -e "  ${W}Puerto MySQL${NC}"
    read -rp "  ${BD}[${DB_PORT}]${NC} → " v; [[ -n "$v" ]] && DB_PORT="$v"

    echo ""
    echo -e "  ${W}Usuario MySQL${NC}"
    read -rp "  ${BD}[${DB_USER}]${NC} → " v; [[ -n "$v" ]] && DB_USER="$v"

    echo ""
    echo -e "  ${W}Contraseña MySQL${NC}"
    read -rsp "  ${BD}[${D}(oculta)${NC}${BD}]${NC} → " v; echo ""
    [[ -n "$v" ]] && DB_PASS="$v"

    echo ""
    echo -e "  ${W}─── Servidor de Juego ─────────────────────────────${NC}"
    echo ""

    echo -e "  ${W}IP de bind${NC} ${D}(0.0.0.0 = todas las interfaces)${NC}"
    read -rp "  ${BD}[${SERVER_IP}]${NC} → " v; [[ -n "$v" ]] && SERVER_IP="$v"

    echo ""
    echo -e "  ${W}Puerto WorldServer${NC} ${D}(clientes WoW se conectan aquí)${NC}"
    read -rp "  ${BD}[${WORLD_PORT}]${NC} → " v; [[ -n "$v" ]] && WORLD_PORT="$v"

    echo ""
    echo -e "  ${W}Puerto AuthServer${NC} ${D}(login/realm list)${NC}"
    read -rp "  ${BD}[${AUTH_PORT}]${NC} → " v; [[ -n "$v" ]] && AUTH_PORT="$v"

    echo ""
    info "DB:       ${BD}${DB_USER}@${DB_HOST}:${DB_PORT}${NC}"
    info "BindIP:   ${BD}${SERVER_IP}${NC}"
    info "World:    ${BD}${WORLD_PORT}${NC}  Auth: ${BD}${AUTH_PORT}${NC}"
    echo ""

    props_save
    pause
}

# ─── Apply settings to .conf ──────────────────────────────────────────────────
# Reemplaza un campo en un .conf: apply_conf_field <file> <key> <value>
apply_conf_field() {
    local file="$1" key="$2" value="$3"
    # Escapa caracteres que romperían el delimitador | de sed
    local escaped_value
    escaped_value=$(printf '%s\n' "$value" | sed 's/[&\\/]/\\&/g')
    sed -i "s|^${key}[[:space:]]*=.*|${key} = ${escaped_value}|" "$file"
}

apply_conf_settings() {
    local etc_dir="${INSTALL_DIR}/etc"
    local world_conf="${etc_dir}/worldserver.conf"
    local auth_conf="${etc_dir}/authserver.conf"
    local data_dir="${INSTALL_DIR}/data"

    local auth_conn="\"${DB_HOST};${DB_PORT};${DB_USER};${DB_PASS};acore_auth\""
    local world_conn="\"${DB_HOST};${DB_PORT};${DB_USER};${DB_PASS};acore_world\""
    local char_conn="\"${DB_HOST};${DB_PORT};${DB_USER};${DB_PASS};acore_characters\""

    if [[ -f "$world_conf" ]]; then
        step "Aplicando configuración a worldserver.conf..."
        apply_conf_field "$world_conf" "LoginDatabaseInfo"     "$auth_conn"
        apply_conf_field "$world_conf" "WorldDatabaseInfo"     "$world_conn"
        apply_conf_field "$world_conf" "CharacterDatabaseInfo" "$char_conn"
        apply_conf_field "$world_conf" "BindIP"                "\"${SERVER_IP}\""
        apply_conf_field "$world_conf" "WorldServerPort"       "$WORLD_PORT"
        apply_conf_field "$world_conf" "DataDir"               "\"${data_dir}\""
        ok "worldserver.conf actualizado."
    fi

    if [[ -f "$auth_conf" ]]; then
        step "Aplicando configuración a authserver.conf..."
        apply_conf_field "$auth_conf" "LoginDatabaseInfo" "$auth_conn"
        apply_conf_field "$auth_conf" "BindIP"            "\"${SERVER_IP}\""
        apply_conf_field "$auth_conf" "RealmServerPort"   "$AUTH_PORT"
        ok "authserver.conf actualizado."
    fi
}

# ─── Create .conf from .dist ──────────────────────────────────────────────────
setup_conf_files() {
    local etc_dir="${INSTALL_DIR}/etc"
    [[ -d "$etc_dir" ]] || return

    echo ""
    step "Verificando archivos de configuración en ${etc_dir}..."

    local copied=0
    for dist in "${etc_dir}"/*.conf.dist; do
        [[ -f "$dist" ]] || continue
        local conf="${dist%.dist}"
        if [[ ! -f "$conf" ]]; then
            cp "$dist" "$conf"
            ok "Creado: $(basename "$conf")"
            (( copied++ )) || true
        else
            info "Ya existe: $(basename "$conf")"
        fi
    done

    [[ $copied -eq 0 ]] && info "Todos los .conf ya existían, sin cambios."

    apply_conf_settings
}

# ─── 3. Dependencies ──────────────────────────────────────────────────────────
install_deps() {
    section "Dependencias del sistema"

    local pkgs_apt="git cmake make gcc g++ clang libmysqlclient-dev libssl-dev
                    libbz2-dev libreadline-dev libncurses-dev libboost-all-dev
                    build-essential autoconf p7zip screen curl wget"

    local pkgs_dnf="git cmake make gcc gcc-c++ clang mysql-devel openssl-devel
                    bzip2-devel readline-devel ncurses-devel boost-devel
                    autoconf p7zip screen curl wget"

    local pkgs_pac="git cmake make gcc clang libmariadbclient openssl
                    boost screen curl wget"

    if command -v apt-get &>/dev/null; then
        step "Actualizando apt..."
        sudo apt-get update -qq
        step "Instalando paquetes..."
        # shellcheck disable=SC2086
        sudo apt-get install -y $pkgs_apt

    elif command -v dnf &>/dev/null; then
        step "Instalando paquetes (dnf)..."
        # shellcheck disable=SC2086
        sudo dnf install -y $pkgs_dnf

    elif command -v yum &>/dev/null; then
        step "Instalando paquetes (yum)..."
        # shellcheck disable=SC2086
        sudo yum install -y $pkgs_dnf

    elif command -v pacman &>/dev/null; then
        step "Instalando paquetes (pacman)..."
        # shellcheck disable=SC2086
        sudo pacman -Sy --noconfirm $pkgs_pac

    else
        warn "Gestor de paquetes no reconocido."
        warn "Instala manualmente: git cmake gcc g++ libmysqlclient-dev libssl-dev libboost-all-dev"
    fi

    ok "Dependencias instaladas."
    pause
}

# ─── 4. Clone / Update ────────────────────────────────────────────────────────
clone_or_update() {
    section "Repositorio"

    info "URL:     ${BD}${REPO_URL}${NC}"
    info "Destino: ${BD}${SOURCE_DIR}${NC}"
    echo ""

    if [[ -d "${SOURCE_DIR}/.git" ]]; then
        warn "El repositorio ya existe en ${SOURCE_DIR}"
        if confirm "¿Actualizar? (git pull + submodules)"; then
            step "Actualizando..."
            git -C "$SOURCE_DIR" pull --ff-only
            git -C "$SOURCE_DIR" submodule update --init --recursive
            ok "Repositorio actualizado."
        fi
    else
        if confirm "¿Clonar AzerothCore en ${SOURCE_DIR}?"; then
            step "Clonando (puede tardar varios minutos)..."
            git clone --depth 1 "$REPO_URL" "$SOURCE_DIR"
            git -C "$SOURCE_DIR" submodule update --init --recursive
            ok "Repositorio clonado."
        fi
    fi

    pause
}

# ─── 5. Build ─────────────────────────────────────────────────────────────────
build() {
    section "Compilación"

    if [[ ! -d "$SOURCE_DIR" ]]; then
        err "Código fuente no encontrado: ${SOURCE_DIR}"
        err "Clona el repositorio primero (opción 4)."
        pause; return
    fi

    local jobs
    jobs=$(nproc)

    info "Fuente:    ${BD}${SOURCE_DIR}${NC}"
    info "Build dir: ${BD}${BUILD_DIR}${NC}"
    info "Instalar:  ${BD}${INSTALL_DIR}${NC}"
    info "Jobs:      ${BD}-j${jobs}${NC}"
    echo ""

    if ! confirm "¿Iniciar compilación? (puede tardar 10–60 minutos)"; then
        pause; return
    fi

    mkdir -p "$BUILD_DIR"

    step "Configurando CMake..."
    cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DSCRIPTS=static \
        -DMODULES=static

    ok "CMake OK."
    step "Compilando con -j${jobs}..."

    make -C "$BUILD_DIR" -j"$jobs"
    ok "Compilación OK."

    step "Instalando binarios en ${INSTALL_DIR}..."
    make -C "$BUILD_DIR" install
    ok "Instalación completada."

    setup_conf_files

    pause
}

# ─── 6. Build with extraction tools ──────────────────────────────────────────
build_tools() {
    section "Compilar con herramientas de extracción"

    if [[ ! -d "$SOURCE_DIR" ]]; then
        err "Código fuente no encontrado: ${SOURCE_DIR}"
        err "Clona el repositorio primero (opción 4)."
        pause; return
    fi

    local jobs
    jobs=$(nproc)

    info "Fuente:    ${BD}${SOURCE_DIR}${NC}"
    info "Instalar:  ${BD}${INSTALL_DIR}${NC}"
    info "Jobs:      ${BD}-j${jobs}${NC}"
    echo ""
    echo -e "  ${Y}  Se compilará con ${BD}TOOLS_BUILD=all${NC}${Y} para generar:${NC}"
    echo -e "  ${D}  • mapextractor     — extrae DBC y mapas${NC}"
    echo -e "  ${D}  • vmap4extractor   — extrae geometría de colisión${NC}"
    echo -e "  ${D}  • vmap4assembler   — ensambla los vmaps${NC}"
    echo -e "  ${D}  • mmaps_generator  — genera mallas de navegación${NC}"
    echo ""

    if ! confirm "¿Compilar con herramientas? (10–60 min)"; then
        pause; return
    fi

    mkdir -p "$BUILD_DIR"

    step "Configurando CMake con TOOLS_BUILD=all..."
    cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DSCRIPTS=static \
        -DMODULES=static \
        -DTOOLS_BUILD=all

    ok "CMake OK."
    step "Compilando con -j${jobs}..."
    make -C "$BUILD_DIR" -j"$jobs"
    ok "Compilación OK."

    step "Instalando en ${INSTALL_DIR}..."
    make -C "$BUILD_DIR" install
    ok "Herramientas instaladas en: ${INSTALL_DIR}/bin/"

    echo ""
    info "Binarios disponibles:"
    for bin in mapextractor vmap4extractor vmap4assembler mmaps_generator; do
        if [[ -f "${INSTALL_DIR}/bin/${bin}" ]]; then
            ok "${bin}"
        else
            warn "${bin} — no encontrado"
        fi
    done

    setup_conf_files
    pause
}

# ─── 7. WoW Client Dir ────────────────────────────────────────────────────────
ask_client_dir() {
    section "Directorio del Cliente WoW"

    echo -e "  ${Y}${BD}  REQUISITOS PARA LA EXTRACCIÓN DE MAPAS${NC}"
    echo ""
    echo -e "  ${W}  1. Cliente original de WoW 3.3.5a (build 12340)${NC}"
    echo -e "  ${D}     Descargado de una fuente legítima. Versión exacta requerida.${NC}"
    echo ""
    echo -e "  ${W}  2. El directorio debe contener:${NC}"
    echo -e "  ${D}     • Wow.exe  (o Wow)${NC}"
    echo -e "  ${D}     • Data/    (directorio con archivos MPQ)${NC}"
    echo ""
    echo -e "  ${W}  3. Los extractores deben estar compilados:${NC}"
    echo -e "  ${D}     Usa la opción ${BD}8) Compilar herramientas${NC}${D} antes de extraer.${NC}"
    echo -e "  ${D}     Los binarios se copiarán automáticamente al cliente.${NC}"
    echo ""
    echo -e "  ${W}  4. Espacio en disco requerido (aprox.):${NC}"
    echo -e "  ${D}     • maps  / dbc  →  ~500 MB${NC}"
    echo -e "  ${D}     • vmaps        →  ~1.5 GB${NC}"
    echo -e "  ${D}     • mmaps        →  ~2.5 GB  (generación: varias horas)${NC}"
    echo ""

    echo -e "  ${W}Directorio del cliente WoW 3.3.5a${NC}"
    local default="${CLIENT_DIR:-/opt/wow-client}"
    read -rp "  ${BD}[${default}]${NC} → " v
    [[ -n "$v" ]] && CLIENT_DIR="$v" || CLIENT_DIR="$default"

    echo ""

    if [[ ! -d "$CLIENT_DIR" ]]; then
        warn "El directorio no existe: ${CLIENT_DIR}"
        warn "Asegúrate de que exista antes de extraer mapas."
    elif [[ ! -d "${CLIENT_DIR}/Data" ]]; then
        warn "No se encontró el subdirectorio Data/ en: ${CLIENT_DIR}"
        warn "Verifica que sea el cliente correcto (3.3.5a build 12340)."
    else
        ok "Directorio del cliente OK: ${CLIENT_DIR}"
    fi

    echo ""
    props_save
    pause
}

# ─── 8. Extract Maps ──────────────────────────────────────────────────────────
extract_maps() {
    section "Extracción de Mapas"

    local jobs
    jobs=$(nproc)
    local bin_dir="${INSTALL_DIR}/bin"
    local data_dir="${INSTALL_DIR}/data"

    # ── Validaciones previas ──────────────────────────────────────────────────
    local errors=0

    if [[ -z "$CLIENT_DIR" || ! -d "$CLIENT_DIR" ]]; then
        err "Directorio del cliente no configurado o no existe."
        err "Configura la ruta primero (opción 7)."
        (( errors++ )) || true
    elif [[ ! -d "${CLIENT_DIR}/Data" ]]; then
        err "No se encontró Data/ en: ${CLIENT_DIR}"
        err "Asegúrate de usar el cliente WoW 3.3.5a build 12340."
        (( errors++ )) || true
    fi

    local missing_bins=()
    for bin in mapextractor vmap4extractor vmap4assembler mmaps_generator; do
        [[ -f "${bin_dir}/${bin}" ]] || missing_bins+=("$bin")
    done

    if [[ ${#missing_bins[@]} -gt 0 ]]; then
        err "Faltan binarios de extracción en ${bin_dir}/:"
        for b in "${missing_bins[@]}"; do err "  • ${b}"; done
        err "Compila las herramientas primero (opción 8)."
        (( errors++ )) || true
    fi

    if [[ $errors -gt 0 ]]; then
        pause; return
    fi

    # ── Resumen ───────────────────────────────────────────────────────────────
    echo -e "  ${Y}${BD}  AVISO — Este proceso puede tardar varias horas${NC}"
    echo ""
    info "Cliente:     ${BD}${CLIENT_DIR}${NC}"
    info "Destino:     ${BD}${data_dir}${NC}"
    info "Núcleos CPU: ${BD}${jobs}${NC}"
    echo ""
    echo -e "  ${W}  Pasos que se ejecutarán:${NC}"
    echo -e "  ${D}  1. mapextractor     → dbc/  maps/${NC}"
    echo -e "  ${D}  2. vmap4extractor   → Buildings/${NC}"
    echo -e "  ${D}  3. vmap4assembler   → vmaps/${NC}"
    echo -e "  ${D}  4. mmaps_generator  → mmaps/   (puede tardar 4–24 h)${NC}"
    echo ""
    echo -e "  ${Y}  El proceso usa ${BD}${jobs} núcleos${NC}${Y} de CPU al máximo.${NC}"
    echo -e "  ${Y}  No cierres esta terminal durante la extracción.${NC}"
    echo ""

    if ! confirm "¿Iniciar extracción completa?"; then
        pause; return
    fi

    mkdir -p "$data_dir"

    # Copiar binarios al directorio del cliente para que los encuentren
    step "Copiando binarios al directorio del cliente..."
    for bin in mapextractor vmap4extractor vmap4assembler mmaps_generator; do
        cp -f "${bin_dir}/${bin}" "${CLIENT_DIR}/${bin}"
    done
    ok "Binarios copiados."

    # ── Paso 1: mapextractor ──────────────────────────────────────────────────
    echo ""
    echo -e "  ${C}${BD}[1/4]${NC} mapextractor — extrayendo DBC y mapas..."
    (
        cd "$CLIENT_DIR"
        ./mapextractor
    )
    ok "mapextractor completado."

    # ── Paso 2: vmap4extractor ────────────────────────────────────────────────
    echo ""
    echo -e "  ${C}${BD}[2/4]${NC} vmap4extractor — extrayendo geometría de colisión..."
    (
        cd "$CLIENT_DIR"
        mkdir -p Buildings vmaps
        ./vmap4extractor
    )
    ok "vmap4extractor completado."

    # ── Paso 3: vmap4assembler ────────────────────────────────────────────────
    echo ""
    echo -e "  ${C}${BD}[3/4]${NC} vmap4assembler — ensamblando vmaps..."
    (
        cd "$CLIENT_DIR"
        ./vmap4assembler Buildings vmaps
    )
    ok "vmap4assembler completado."

    # ── Paso 4: mmaps_generator ───────────────────────────────────────────────
    echo ""
    echo -e "  ${C}${BD}[4/4]${NC} mmaps_generator — generando mallas de navegación..."
    echo -e "  ${Y}  Usando ${BD}${jobs} threads${NC}${Y}. Este paso puede tardar horas.${NC}"
    (
        cd "$CLIENT_DIR"
        mkdir -p mmaps
        ./mmaps_generator --threads "$jobs"
    )
    ok "mmaps_generator completado."

    # ── Mover resultados ──────────────────────────────────────────────────────
    echo ""
    step "Moviendo datos extraídos a ${data_dir}..."

    for dir in dbc maps vmaps mmaps Cameras; do
        if [[ -d "${CLIENT_DIR}/${dir}" ]]; then
            rm -rf "${data_dir:?}/${dir}"
            mv "${CLIENT_DIR}/${dir}" "${data_dir}/${dir}"
            ok "→ ${data_dir}/${dir}"
        fi
    done

    # Limpiar Buildings (ya no se necesita)
    rm -rf "${CLIENT_DIR}/Buildings"

    # Limpiar binarios copiados
    for bin in mapextractor vmap4extractor vmap4assembler mmaps_generator; do
        rm -f "${CLIENT_DIR}/${bin}"
    done

    echo ""
    ok "Extracción completa. Datos en: ${data_dir}"
    echo ""
    info "El campo ${BD}DataDir${NC} en worldserver.conf apunta a: ${BD}${data_dir}${NC}"
    info "Aplica la config con la opción 7 si aún no lo has hecho."

    pause
}

# ─── MySQL admin helpers ──────────────────────────────────────────────────────

# Ejecuta mysql con las credenciales de administrador de sesión
mysql_a() {
    if [[ -n "$_ADMIN_PASS" ]]; then
        mysql -h"$DB_HOST" -P"$DB_PORT" -u"$_ADMIN_USER" -p"$_ADMIN_PASS" \
              --connect-timeout=10 "$@"
    else
        mysql -h"$DB_HOST" -P"$DB_PORT" -u"$_ADMIN_USER" \
              --connect-timeout=10 "$@"
    fi
}

# Importa todos los .sql de un directorio en orden, mostrando progreso
db_import_dir() {
    local db="$1" dir="$2"
    [[ -d "$dir" ]] || { warn "Directorio no encontrado: ${dir}"; return; }

    local files=()
    while IFS= read -r -d '' f; do
        files+=("$f")
    done < <(find "$dir" -maxdepth 1 -name "*.sql" -print0 | sort -z)

    local total=${#files[@]}
    if [[ $total -eq 0 ]]; then
        warn "Sin archivos SQL en: ${dir}"; return
    fi

    local i=0
    for f in "${files[@]}"; do
        (( i++ )) || true
        printf "\r  ${B}›${NC}  [%d/%d] %s                    " \
               "$i" "$total" "$(basename "$f")"
        mysql_a "$db" < "$f"
    done
    echo ""
    ok "${db} — ${total} archivo(s) importado(s)."
}

# Aplica actualizaciones SQL de un directorio (continúa en errores menores)
db_apply_updates() {
    local db="$1" dir="$2"
    [[ -d "$dir" ]] || return

    local count=0
    while IFS= read -r -d '' f; do
        mysql_a --force "$db" < "$f" 2>/dev/null
        (( count++ )) || true
    done < <(find "$dir" -name "*.sql" -print0 | sort -z)

    if [[ $count -gt 0 ]]; then
        ok "${db} — ${count} actualización(es) aplicada(s)."
    else
        info "${db} — sin actualizaciones en: $(basename "$dir")"
    fi
}

# ─── 11. Database Setup ───────────────────────────────────────────────────────
setup_database() {
    section "Instalación de Bases de Datos"

    echo -e "  ${W}  Se crearán / actualizarán las siguientes bases de datos:${NC}"
    echo ""
    echo -e "  ${D}  • ${BD}acore_auth${NC}${D}       — Cuentas, realm list, bans${NC}"
    echo -e "  ${D}  • ${BD}acore_characters${NC}${D} — Personajes, inventarios, progreso${NC}"
    echo -e "  ${D}  • ${BD}acore_world${NC}${D}      — Criaturas, items, quests, loot${NC}"
    echo ""
    info "Servidor:  ${BD}${DB_HOST}:${DB_PORT}${NC}"
    info "Usuario juego: ${BD}${DB_USER}${NC}  ${D}(se creará si no existe)${NC}"

    if [[ ! -d "${SOURCE_DIR}/data/sql/base" ]]; then
        echo ""
        err "No se encontraron los archivos SQL base en:"
        err "  ${SOURCE_DIR}/data/sql/base"
        err "Clona el repositorio primero (opción 4)."
        pause; return
    fi

    # ── Credenciales de administrador ─────────────────────────────────────────
    echo ""
    echo -e "  ${W}─── Credenciales de administrador MySQL ───────────${NC}"
    echo -e "  ${D}  Se usan solo para crear bases de datos y usuario.${NC}"
    echo -e "  ${D}  No se guardan en disco.${NC}"
    echo ""

    local default_admin="${_ADMIN_USER:-root}"
    echo -e "  ${W}Usuario administrador MySQL${NC}"
    read -rp "  ${BD}[${default_admin}]${NC} → " v
    _ADMIN_USER="${v:-$default_admin}"

    echo ""
    echo -e "  ${W}Contraseña administrador MySQL${NC} ${D}(vacío = sin contraseña)${NC}"
    read -rsp "  ${BD}[(oculta)]${NC} → " _ADMIN_PASS; echo ""

    # ── Test de conexión ──────────────────────────────────────────────────────
    echo ""
    step "Verificando conexión MySQL..."
    if ! mysql_a -e "SELECT 1;" &>/dev/null; then
        err "No se pudo conectar a MySQL."
        err "Verifica host/puerto en la opción 2, y las credenciales de admin."
        _ADMIN_PASS=""
        pause; return
    fi
    ok "Conexión OK."

    if ! confirm "¿Crear bases de datos, usuario y poblar con SQL base?"; then
        pause; return
    fi

    # ── Crear bases de datos ──────────────────────────────────────────────────
    echo ""
    step "Creando bases de datos..."
    for db in acore_auth acore_characters acore_world; do
        mysql_a -e \
            "CREATE DATABASE IF NOT EXISTS \`${db}\`
             DEFAULT CHARACTER SET utf8mb4
             COLLATE utf8mb4_unicode_ci;" \
            && ok "${db}" \
            || { err "Error creando: ${db}"; pause; return; }
    done

    # ── Crear usuario y permisos ──────────────────────────────────────────────
    echo ""
    step "Creando usuario '${DB_USER}' y asignando permisos..."
    mysql_a -e "
        CREATE USER IF NOT EXISTS '${DB_USER}'@'%'
            IDENTIFIED BY '${DB_PASS}';
        CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost'
            IDENTIFIED BY '${DB_PASS}';
        GRANT ALL PRIVILEGES ON \`acore_auth\`.*       TO '${DB_USER}'@'%';
        GRANT ALL PRIVILEGES ON \`acore_characters\`.* TO '${DB_USER}'@'%';
        GRANT ALL PRIVILEGES ON \`acore_world\`.*      TO '${DB_USER}'@'%';
        GRANT ALL PRIVILEGES ON \`acore_auth\`.*       TO '${DB_USER}'@'localhost';
        GRANT ALL PRIVILEGES ON \`acore_characters\`.* TO '${DB_USER}'@'localhost';
        GRANT ALL PRIVILEGES ON \`acore_world\`.*      TO '${DB_USER}'@'localhost';
        FLUSH PRIVILEGES;
    " && ok "Usuario '${DB_USER}' configurado." \
      || { err "Error configurando usuario."; pause; return; }

    # ── Importar SQL base ─────────────────────────────────────────────────────
    local sql_base="${SOURCE_DIR}/data/sql/base"

    echo ""
    echo -e "  ${C}${BD}[1/3]${NC} Importando ${BD}acore_auth${NC}..."
    db_import_dir acore_auth "${sql_base}/db_auth"

    echo ""
    echo -e "  ${C}${BD}[2/3]${NC} Importando ${BD}acore_characters${NC}..."
    db_import_dir acore_characters "${sql_base}/db_characters"

    echo ""
    echo -e "  ${C}${BD}[3/3]${NC} Importando ${BD}acore_world${NC} ${D}(puede tardar varios minutos)...${NC}"
    db_import_dir acore_world "${sql_base}/db_world"

    # ── Aplicar actualizaciones ───────────────────────────────────────────────
    echo ""
    step "Aplicando actualizaciones SQL del repositorio..."

    local sql_upd="${SOURCE_DIR}/data/sql/updates"

    db_apply_updates acore_auth       "${sql_upd}/db_auth"
    db_apply_updates acore_characters "${sql_upd}/db_characters"
    db_apply_updates acore_world      "${sql_upd}/db_world"

    echo ""
    step "Aplicando actualizaciones SQL pendientes..."

    db_apply_updates acore_auth       "${sql_upd}/pending_db_auth"
    db_apply_updates acore_characters "${sql_upd}/pending_db_characters"
    db_apply_updates acore_world      "${sql_upd}/pending_db_world"

    echo ""
    ok "Instalación de bases de datos completada."
    echo ""
    info "Los archivos .conf ya están configurados para conectarse con"
    info "  ${BD}${DB_USER}@${DB_HOST}:${DB_PORT}${NC}"
    info "Si cambiaste las credenciales usa la opción ${BD}6${NC} para re-aplicarlas."

    pause
}

# ─── 12. Update all ───────────────────────────────────────────────────────────
update() {
    section "Actualizar AzerothCore"

    if [[ ! -f "$PROPS_FILE" ]]; then
        err "No hay configuración guardada en ${PROPS_FILE}"
        err "Ejecuta la instalación primero."
        pause; return
    fi

    info "Fuente:   ${BD}${SOURCE_DIR}${NC}"
    info "Instalar: ${BD}${INSTALL_DIR}${NC}"
    echo ""

    if ! confirm "¿Actualizar repo y recompilar?"; then
        pause; return
    fi

    step "Actualizando repositorio..."
    git -C "$SOURCE_DIR" pull --ff-only
    git -C "$SOURCE_DIR" submodule update --init --recursive
    ok "Repositorio actualizado."

    local jobs
    jobs=$(nproc)

    step "Recompilando con -j${jobs}..."
    cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DSCRIPTS=static \
        -DMODULES=static

    make -C "$BUILD_DIR" -j"$jobs"
    make -C "$BUILD_DIR" install
    ok "Actualización completada."

    setup_conf_files

    pause
}

# ─── Main Menu ────────────────────────────────────────────────────────────────
main_menu() {
    while true; do
        banner

        if [[ -f "$PROPS_FILE" ]]; then
            echo -e "  ${D}Install: ${INSTALL_DIR}${NC}"
            echo -e "  ${D}DB:      ${DB_USER}@${DB_HOST}:${DB_PORT}  │  World: ${SERVER_IP}:${WORLD_PORT}  Auth: ${AUTH_PORT}${NC}"
            local client_label="${CLIENT_DIR:-${R}no configurado${NC}}"
            echo -e "  ${D}Cliente: ${client_label}${NC}"
        else
            echo -e "  ${Y}  Sin configuración guardada — configura las rutas primero (opción 1).${NC}"
        fi

        echo ""
        echo -e "  ${W}${BD}── Configuración ─────────────────────────────────${NC}"
        echo -e "  ${C}${BD} 1)${NC}  Rutas de instalación"
        echo -e "  ${C}${BD} 2)${NC}  MySQL y puertos del servidor"
        echo -e "  ${C}${BD} 7)${NC}  Directorio del cliente WoW  ${D}(para extracción)${NC}"
        echo ""
        echo -e "  ${W}${BD}── Instalación ───────────────────────────────────${NC}"
        echo -e "  ${C}${BD} 3)${NC}  Instalar dependencias del sistema"
        echo -e "  ${C}${BD} 4)${NC}  Clonar / Actualizar repositorio"
        echo -e "  ${C}${BD} 5)${NC}  Compilar e instalar servidor   ${D}(cmake → make → install)${NC}"
        echo -e "  ${C}${BD} 8)${NC}  Compilar herramientas extracción ${D}(TOOLS_BUILD=all)${NC}"
        echo ""
        echo -e "  ${W}${BD}── Base de Datos ──────────────────────────────────${NC}"
        echo -e "  ${C}${BD}11)${NC}  Instalar bases de datos        ${D}(crear + usuario + SQL base)${NC}"
        echo ""
        echo -e "  ${W}${BD}── Mapas ──────────────────────────────────────────${NC}"
        echo -e "  ${C}${BD} 9)${NC}  Extraer mapas del cliente      ${D}(mapas + vmaps + mmaps)${NC}"
        echo ""
        echo -e "  ${W}${BD}── Mantenimiento ─────────────────────────────────${NC}"
        echo -e "  ${C}${BD} 6)${NC}  Aplicar config a .conf  ${D}(sin recompilar)${NC}"
        echo -e "  ${C}${BD}10)${NC}  Actualizar todo         ${D}(pull + recompilar)${NC}"
        echo ""
        echo -e "  ${R}${BD} 0)${NC}  Salir"
        echo ""
        read -rp "  Selecciona: " choice

        case "$choice" in
            1)  ask_paths ;;
            2)  ask_db_config ;;
            3)  install_deps ;;
            4)  clone_or_update ;;
            5)  build ;;
            6)  setup_conf_files; pause ;;
            7)  ask_client_dir ;;
            8)  build_tools ;;
            9)  extract_maps ;;
            10) update ;;
            11) setup_database ;;
            0)  echo ""; ok "¡Hasta pronto!"; echo ""; exit 0 ;;
            *)  warn "Opción inválida."; sleep 1 ;;
        esac
    done
}

main_menu
