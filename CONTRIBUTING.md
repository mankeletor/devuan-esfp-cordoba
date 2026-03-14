# Guía de Contribución — CorbexOS 📀🇦🇷

Si llegaste hasta acá es porque el proyecto te interesa, y eso ya vale. CorbexOS es un esfuerzo para que las netbooks escolares de Córdoba arranquen con un sistema digno, completo y listo para usar — sin que un técnico tenga que configurar cada equipo a mano. Cualquier mejora suma.

---

## 🚀 Cómo Empezar

### Requisitos del Entorno de Build

Necesitás un sistema Linux (preferentemente Debian/Devuan) con:

```bash
sudo apt install xorriso cpio rsync wget curl dpkg-dev flatpak shellcheck qemu-system-x86
```

Al menos **10GB de espacio libre** en disco para las ISOs base, el directorio de trabajo y la ISO generada.

### Configuración Inicial

```bash
git clone https://github.com/mankeletor/corbex-os.git
cd corbex-os
cp config.env.example config.env
nano config.env   # Apuntar las rutas a las ISOs de Devuan Excalibur
```

---

## 🛠️ Filosofía del Proyecto: KISS + Modular

El proyecto está organizado en módulos independientes orquestados por `main.sh`. Cada módulo hace una sola cosa. Antes de tocar código, entendé el flujo:

```
main.sh → 01_check_deps → 02_extract_iso → 04_repo_local → 03_build_initrd → 05_build_iso
```

**Reglas básicas:**

- **No edites `main.sh`** a menos que necesites cambiar el flujo de ejecución entre módulos.
- **Nuevas funcionalidades** → creá un script `06_nombre.sh` en `/modules/` y registralo en `main.sh`.
- **Configuración del escritorio MATE** → va en `templates/corbex.dconf` o en `scripts_aux/postinst_final.sh`.
- **Paquetes nuevos** → agregá a `pkgs_manual_clean.txt`. El módulo 04 resuelve dependencias automáticamente.
- **Extras offline** (apps que no están en repos Devuan) → el patrón es: descarga en `04_repo_local.sh` → instalación en `postinst_final.sh`. Ver cómo están implementados PSeInt, Antigravity y Chrome como referencia.

---

## 🧪 Ciclo de Pruebas

Antes de enviar un cambio, verificá:

**1. Sintaxis**
```bash
shellcheck modules/*.sh scripts_aux/postinst_final.sh
```

**2. Build completo**
```bash
sudo bash main.sh
```

**3. Booteo en QEMU**
```bash
qemu-system-x86_64 -cdrom /ruta/a/corbex-os.iso -m 2048 -boot d
```

**4. Instalación completa** — dejá que el instalador corra hasta el final y verificá que el sistema arranque correctamente con autologin del usuario `alumno`.

---

## 📬 Cómo Enviar tus Mejoras

1. Fork del repositorio.
2. Creá una rama descriptiva:
   ```bash
   git checkout -b fix/audio-intel-hda
   git checkout -b feat/agregar-scratch-flatpak
   ```
3. Commits descriptivos usando prefijos semánticos:
   ```
   fix: corregir inyección de locales en postinst_final.sh
   feat: agregar instalación offline de Scratch vía Flatpak
   docs: actualizar README con instrucciones de build
   refactor: simplificar discovery de mirror en 3.5_build_source.sh
   ```
4. Abrí un Pull Request con descripción del cambio y, si aplica, resultado del test en QEMU.

---

## 🎯 Áreas Prioritarias

Si no sabés por dónde arrancar, estas son las áreas donde más se necesita trabajo:

**🔊 Audio**
Algunos modelos de netbooks Juana Manso / Conectar Igualdad tienen hardware de audio Intel HDA con volumen muy bajo por defecto. Mejorar la detección automática del hardware y aplicar los ajustes de ALSA correspondientes en el postinst.

**🔋 Energía**
Optimización de consumo de batería bajo OpenRC: `tlp`, `cpufrequtils`, gestión de suspensión. Las netbooks escolares no siempre tienen acceso a corriente durante la clase.

**🎨 Branding**
Arte visual para el cargador de arranque ISOLINUX (`/templates/isolinux.cfg`). El splash screen actual es texto ASCII — una imagen PNG 640x480 marcaría bastante la diferencia en la experiencia de instalación.

**🧪 Testing automatizado**
Script que levante la ISO en QEMU y verifique automáticamente que el sistema arrancó, que el usuario `alumno` tiene sesión activa y que los paquetes críticos están instalados.

---

## ⚖️ Licencia

Al contribuir, aceptás que tu código será liberado bajo **GNU GPL v3**.
