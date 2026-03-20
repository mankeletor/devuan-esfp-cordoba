# 🐧 Corbex-OS (Córdoba Excalibur Operating System)

> *"El año pasado customicé Linux Mint MATE para las notebooks escolares de las ESFP de Córdoba — equivalente a comprar un auto base y llevarlo a un taller de tuning según las especificaciones. Este año con CorbexOS, equivale a pedir el auto customizado directamente desde la fábrica. Así es, ¡pasamos del taller a la fábrica!"*

CorbexOS es una imagen ISO de **Devuan GNU/Linux (Excalibur)** construida desde cero para las netbooks de las escuelas secundarias de Córdoba. No es una instalación manual ni un script de post-configuración: es una ISO que ya sale del horno con todo adentro — sistema, escritorio, software educativo, firmwares, configuración de red y usuarios. El docente o técnico graba en un USB, instala, y listo.

---

## ¿Por qué Devuan y no Ubuntu/Mint?

Las netbooks escolares tienen hardware acotado (4GB RAM, procesadores Intel de generaciones anteriores). Devuan corre sobre **OpenRC** en lugar de systemd, lo que se traduce en un arranque más rápido, menos procesos en memoria y más recursos disponibles para el alumno. El escritorio **MATE** completa la ecuación: liviano, estable y familiar para cualquiera que haya usado Windows.

---

## 🚀 Qué trae CorbexOS

| Área | Detalle |
|---|---|
| **Base** | Devuan Excalibur (Stable) — sin systemd |
| **Init** | OpenRC con arranque paralelo optimizado |
| **Escritorio** | MATE Desktop |
| **Ofimática** | LibreOffice en español (es-AR) |
| **Programación** | Python 3, PSeInt, Git, Node.js |
| **Diseño** | GIMP, Inkscape, Avidemux, Audacity |
| **Browser** | Google Chrome (con soporte de sync de cuenta Google) |
| **IDE educativo** | Antigravity (offline, instalación automática) |
| **Red** | NetworkManager, WiFi, firmwares Intel/Realtek incluidos |
| **Instalación** | 100% desatendida vía `preseed.cfg` — sin intervención humana |
| **Idioma** | Español Argentina en todo el sistema y aplicaciones |

---

## 📂 Estructura del Repositorio

```
corbex-os/
├── main.sh                  # Orquestador principal — ejecuta los módulos en orden
├── config.env               # Variables de configuración (rutas de ISOs, versión, etc.)
├── preseed.cfg              # Instalación desatendida: idioma, usuario, repos, paquetes
├── rc.conf                  # Configuración de OpenRC
├── pkgs_manual_clean.txt    # Lista semilla de paquetes base
├── modules/
│   ├── 01_check_deps.sh     # Verifica dependencias del sistema de build
│   ├── 02_extract_iso.sh    # Extrae la ISO Netinstall base
│   ├── 03_build_initrd.sh   # Modifica el initrd e inyecta preseed + postinst
│   ├── 04_repo_local.sh     # Arma el repo local offline + descarga extras
│   └── 05_build_iso.sh      # Reensambla la ISO final con xorriso
├── scripts_aux/
│   └── postinst_final.sh    # Post-instalación dentro del chroot del target
├── templates/
│   ├── isolinux.cfg         # Menú de arranque (ISOLINUX)
│   ├── rc.conf              # Plantilla de OpenRC
│   └── corbex.dconf         # Configuración global de MATE vía dconf
└── obsolete/                # Archivos en desuso (no utilizar)
```

---

## 🛠️ Cómo Construir la ISO

### Requisitos Previos

**ISOs base necesarias:**

```
# ISO Netinstall de Devuan Excalibur
https://mirror.leaseweb.com/devuan/devuan_excalibur/installer-iso/devuan_excalibur_6.1.0_amd64_netinstall.iso

# ISO Pool1 (repositorio offline de paquetes)
https://mirror.leaseweb.com/devuan/devuan_excalibur/installer-iso/devuan_excalibur_6.1.0_amd64_pool1.iso
```

**Dependencias del sistema de build:**

```bash
sudo apt install xorriso cpio rsync wget curl dpkg-dev flatpak
```

### Instrucciones

```bash
# 1. Clonar el repositorio
git clone https://github.com/mankeletor/corbex-os.git
cd corbex-os

# 2. Configurar rutas de las ISOs descargadas
nano config.env

# 3. Ejecutar el build completo como root
sudo bash main.sh
```

El proceso demora entre 15 y 40 minutos dependiendo de la velocidad del mirror y la conexión. Al finalizar, la ISO queda en el directorio configurado en `config.env` junto con su `.md5`.

**Tip:** Si querés limpiar la caché de paquetes y forzar una descarga limpia:
```bash
sudo bash main.sh --clean
```

---

## 📥 Descarga de la ISO Lista para Usar

Si no querés compilar la ISO por tu cuenta, podés descargar la versión estable lista para grabar:

> ⚠️ **Enlace de descarga próximamente disponible.**

### ✅ Verificar Integridad

```bash
md5sum -c corbex-os.iso.md5
```

### 💾 Grabar en USB

```bash
sudo dd if=corbex-os.iso of=/dev/sdX bs=4M status=progress && sync
```

> ⚠️ Reemplazá `/dev/sdX` con el dispositivo correcto. Verificá con `lsblk` antes de ejecutar — este comando sobreescribe el dispositivo sin confirmación.

---

## 🏗️ Cómo Funciona el Build (Resumen Técnico)

1. **Módulo 01** valida que el sistema de build tenga todas las herramientas.
2. **Módulo 02** extrae la ISO Netinstall original.
3. **Módulo 04** resuelve dependencias de paquetes via APT en sandbox aislado, arma el repositorio local offline dentro de la ISO y descarga extras (PSeInt, Antigravity, Avidemux, Google Chrome).
4. **Módulo 03** modifica el initrd: inyecta el `preseed.cfg`, el `postinst_final.sh` y las listas de paquetes.
5. **Módulo 05** reensambla la ISO final con `xorriso`, con soporte BIOS + UEFI.
6. Al instalar, el `preseed.cfg` automatiza todo el instalador Debian/Devuan y al final ejecuta el `postinst_final.sh` dentro del chroot del sistema recién instalado.

---

## 👤 Autor

**Pablo Saquilán** — Maintainer & Dev
📧 [psaquilan82@gmail.com](mailto:psaquilan82@gmail.com)

---

*Hecho desde la educación cordobesa para el mundo.*
