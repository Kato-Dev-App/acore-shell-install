# acore-setup.sh

Script interactivo para instalar, compilar y gestionar un servidor **AzerothCore** (WoW 3.3.5a — Wrath of the Lich King) en Linux.

## Requisitos previos

- Linux (Ubuntu/Debian, Fedora/RHEL, Arch)
- `sudo` disponible para instalar dependencias
- MySQL 8+ accesible (local o remoto)
- Cliente WoW 3.3.5a build 12340 (solo para extracción de mapas)

## Uso

```bash
chmod +x acore-setup.sh
./acore-setup.sh
```

La configuración se guarda automáticamente en `~/.acore-setup.conf` y se carga en cada ejecución.

---

## Menú principal

### Configuración

| Opción | Descripción |
|--------|-------------|
| **1** | Rutas de instalación — directorio de binarios/configs e instalación del servidor |
| **2** | Configuración MySQL (host, puerto, usuario, contraseña) y puertos del servidor |
| **7** | Ruta al directorio del cliente WoW — requerido antes de extraer mapas |
| **12** | Nombre del realm, IP pública e IP local — actualiza directamente la BD |

### Instalación

| Opción | Descripción |
|--------|-------------|
| **3** | Instala las dependencias del sistema (`cmake`, `gcc`, `libmysqlclient`, `boost`, etc.) |
| **4** | Clona el repositorio de AzerothCore o actualiza uno existente (`git pull`) |
| **5** | Compila e instala el servidor completo (`worldserver` + `authserver`) |
| **8** | Compila solo las herramientas de extracción de mapas, en carpeta separada (`build-tools/`) |

> La opción **8** usa `-DAPPS_BUILD=none -DTOOLS_BUILD=maps-only` para no compilar los servidores y reducir el tiempo de compilación.

### Base de datos

| Opción | Descripción |
|--------|-------------|
| **11** | Instalación completa: crea bases de datos, usuario MySQL, importa SQL base y aplica updates |
| **13** | Reset destructivo: hace `DROP` de las 3 DBs, las recrea e importa solo el SQL base sin updates |

> Usar **13** cuando el servidor falla al arrancar por errores de migración (columnas duplicadas, etc.). Al iniciar el servidor después del reset, él aplica los updates automáticamente en orden limpio.

Las bases de datos gestionadas son:
- `acore_auth` — cuentas, realm list, bans
- `acore_characters` — personajes, inventarios, progreso
- `acore_world` — criaturas, items, quests, loot

### Mapas

| Opción | Descripción |
|--------|-------------|
| **9** | Extracción completa de mapas del cliente WoW |

La extracción ejecuta 4 pasos en orden:
1. `map_extractor` → `dbc/` y `maps/`
2. `vmap4_extractor` → `Buildings/`
3. `vmap4_assembler` → `vmaps/`
4. `mmaps_generator` → `mmaps/` *(puede tardar 4–24 horas)*

Los binarios se buscan en `bin/` o en el directorio del cliente. Si están en `bin/`, se copian al cliente automáticamente antes de la extracción y se eliminan al terminar.

### Servidor

| Opción | Descripción |
|--------|-------------|
| **14** | Submenú para iniciar, detener y adjuntarse a la consola de cada servidor |

Los servidores corren en sesiones **screen** nombradas `acore-auth` y `acore-world`.

Submenú de la opción 14:

| | |
|--|--|
| 1 | Iniciar ambos servidores |
| 2 | Detener ambos servidores |
| 3 | Iniciar authserver |
| 4 | Iniciar worldserver |
| 5 | Detener authserver |
| 6 | Detener worldserver |
| 7 | Ver consola authserver |
| 8 | Ver consola worldserver |

> Para salir de la consola sin detener el servidor: `Ctrl+A`, luego `D`.

También se puede acceder directamente desde la terminal:
```bash
screen -r acore-world
screen -r acore-auth
```

### Mantenimiento

| Opción | Descripción |
|--------|-------------|
| **6** | Re-aplica la configuración (DB, IP, puertos) a los `.conf` sin recompilar |
| **10** | `git pull` + recompilación completa del servidor |

---

## Instalación desde cero (orden recomendado)

```
1  → Rutas de instalación
2  → MySQL y puertos
3  → Instalar dependencias
4  → Clonar repositorio
5  → Compilar servidor
11 → Instalar bases de datos
12 → Configurar realm e IPs
7  → Directorio del cliente WoW
8  → Compilar herramientas de extracción
9  → Extraer mapas
14 → Iniciar servidores
```

---

## Archivos generados

| Archivo | Descripción |
|---------|-------------|
| `~/.acore-setup.conf` | Configuración persistente (rutas, DB, IPs, realm) |
| `INSTALL_DIR/etc/*.conf` | Configs del servidor (generadas desde `.conf.dist`) |
| `INSTALL_DIR/data/` | Mapas extraídos del cliente |
| `SOURCE_DIR/build/` | Directorio de compilación del servidor |
| `SOURCE_DIR/build-tools/` | Directorio de compilación de herramientas (separado) |
