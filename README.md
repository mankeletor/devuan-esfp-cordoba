# 🐧 Devuan ESFP Córdoba Edition (Excalibur)

Este proyecto contiene las herramientas y scripts necesarios para generar una imagen ISO personalizada de **Devuan GNU/Linux (Excalibur)**, optimizada específicamente para las netbooks de la **Escuela Secundaria de Formación Profesional (ESFP) Córdoba**.

## 🚀 Características Principales

- **Base:** Devuan Excalibur (Stable) - ¡Libre de Systemd!
- **Sistema de Init:** OpenRC con arranque paralelo optimizado.
- **Escritorio:** MATE Desktop liviano, ideal para 4GB de RAM.
- **Automatización:** Instalación desatendida mediante `preseed.cfg`.
- **Software Incluido:** Repositorio local integrado con suites de oficina, diseño (GIMP, Audacity) y herramientas de programación (Python, Git).
- **Optimización:** Swappiness reducido, autologin configurado y limpieza de servicios innecesarios para mejorar el rendimiento.

## 📂 Estructura del Repositorio

- `scripts/`: Contiene el script principal de customización (`customizar_iso.sh`).
- `configs/`: Archivos de configuración inyectados en el instalador:
  - `preseed.cfg`: Respuestas automáticas para el instalador Debian.
  - `postinst.sh`: Script de post-instalación (configura el escritorio y optimiza el sistema).
  - `rc.conf`: Ajustes para el arranque con OpenRC.
- `data/`: Lista de paquetes a incluir (`pkgs.txt`).

## 🛠️ Cómo construir la ISO

### Requisitos previos
1. Descargar la ISO oficial de Devuan Excalibur Netinstall.
https://mirror.leaseweb.com/devuan/devuan_excalibur/installer-iso/devuan_excalibur_6.1.0_amd64_netinstall.iso
2. Descargar la ISO de la **Pool1** de Devuan (necesaria para el repositorio local).
https://mirror.leaseweb.com/devuan/devuan_excalibur/installer-iso/devuan_excalibur_6.1.0_amd64_pool1.iso

3. Tener instalado: `xorriso`, `cpio`, `rsync`, `isolinux`.

### Instrucciones
1. Clonar este repositorio:
   ```bash
   git clone [https://github.com/mankeletor/devuan-esfp-cordoba.git](https://github.com/mankeletor/devuan-esfp-cordoba.git)
   cd devuan-esfp-cordoba

    Editar las rutas de las ISOs originales en el script scripts/customizar_iso.sh.

    Ejecutar el script como root:
    Bash

    sudo bash scripts/customizar_iso.sh

📥 Descarga de la ISO lista para usar

Si no querés compilar la ISO por tu cuenta, podés descargar la versión estable y lista para grabar en un USB:

## ✅ Verificación de integridad

Después de descargar la ISO, verificá que no esté corrupta:

```bash
# Descargar también el archivo .sha256
sha256sum -c devuan-esfp-cordoba.iso.sha256

👉 DESCARGAR ISO DESDE MEGA

    Nota: Para grabar la ISO en un pendrive, recomendamos usar el comando dd:
    sudo dd if=devuan-esfp-cordoba.iso of=/dev/sdX bs=4M status=progress && sync

👤 Autor

    Pablo Saquilán - Maintainer & Dev - [psaquilan82@gmail.com]

Hecho para la educación técnica de Córdoba.
