#!/usr/bin/env bash
# scripts/03_build_rootfs.sh
# Construye initramfs con BusyBox estático
#
# Lecciones aprendidas (¡todas críticas!):
#   - scripts/config NO existe en BusyBox → usar sed
#   - olddefconfig NO existe en BusyBox → quitarlo
#   - CONFIG_TC=y rompe la compilación con kernels nuevos → poner =n
#   - CONFIG_STATIC=y es OBLIGATORIO o nada funciona
#   - make defconfig puede pedir entrada interactiva → usar yes "" pipe
#   - bzip2 debe estar instalado (manejado en Dockerfile)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUSYBOX_SRC="$WORKSPACE_ROOT/kernel/busybox"
INITRAMFS_DIR="$WORKSPACE_ROOT/kernel/initramfs"
BUILD_DIR="$WORKSPACE_ROOT/kernel/build"
JOBS="$(nproc)"

STUDENT_ID="${STUDENT_ID:-$(git -C "$WORKSPACE_ROOT" config user.name 2>/dev/null \
                | tr ' ' '-' | tr -cd '[:alnum:]-' | head -c 20)}"
STUDENT_ID="${STUDENT_ID:-unnamed}"

CYAN='\033[1;36m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${CYAN}[1/5] Clonando BusyBox...${NC}"
if [ ! -d "$BUSYBOX_SRC" ]; then
  git clone --depth 1 https://git.busybox.net/busybox "$BUSYBOX_SRC"
fi

cd "$BUSYBOX_SRC"

echo -e "${CYAN}[2/5] Configurando BusyBox (static + sin TC)...${NC}"
# yes "" alimenta enter a posibles preguntas interactivas de defconfig
#yes "" | make defconfig >/dev/null 2>&1
make defconfig

# CRÍTICO: editar el .config con sed (BusyBox NO tiene scripts/config)
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
grep -q "^CONFIG_STATIC=y" .config || echo "CONFIG_STATIC=y" >> .config

# CONFIG_TC rompe la compilación con kernels nuevos (error en networking/tc.c)
sed -i 's/^CONFIG_TC=y/CONFIG_TC=n/' .config
sed -i 's/^CONFIG_FEATURE_TC_INGRESS=y/CONFIG_FEATURE_TC_INGRESS=n/' .config

# NOTA: BusyBox NO tiene "make olddefconfig", se compila directo

echo -e "${CYAN}[3/5] Compilando BusyBox estático (~3-5 min)...${NC}"
make -j"$JOBS" 2>&1 | tail -3

# Verificar que quedó estático
if ! file busybox | grep -q "statically linked"; then
  echo -e "${YELLOW}⚠ BusyBox NO quedó estático. Verificando .config...${NC}"
  grep STATIC .config
  exit 1
fi
echo -e "${GREEN}  ✓ BusyBox compilado estáticamente${NC}"

echo -e "${CYAN}[4/5] Instalando BusyBox en initramfs y armando estructura...${NC}"
rm -rf "$INITRAMFS_DIR"
mkdir -p "$INITRAMFS_DIR"
make CONFIG_PREFIX="$INITRAMFS_DIR" install 2>&1 | tail -3

# Estructura mínima
mkdir -p "$INITRAMFS_DIR"/{proc,sys,dev,tmp,etc,root,home/student,run}

# Usuario student (sin privilegios) y root
cat > "$INITRAMFS_DIR/etc/passwd" << 'PASSWD'
root:x:0:0:root:/root:/bin/sh
student:x:1001:1001::/home/student:/bin/sh
PASSWD

cat > "$INITRAMFS_DIR/etc/group" << 'GROUP'
root:x:0:
student:x:1001:
GROUP

# Script init (requiere BINFMT_SCRIPT en el kernel, ya habilitado)
cat > "$INITRAMFS_DIR/init" << INITEOF
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null || /bin/busybox mdev -s
mount -t tmpfs none /tmp
chmod 1777 /tmp
export PATH=/usr/bin:/bin:/sbin:/usr/sbin

# Cargar módulos crypto vulnerables si están como módulos
/bin/busybox modprobe algif_aead 2>/dev/null || true
/bin/busybox modprobe authencesn 2>/dev/null || true

# Hostname con el STUDENT_ID embebido (anti-copia)
hostname "copy-fail-${STUDENT_ID}"

echo ""
echo "  ╔═══════════════════════════════════════════════╗"
echo "  ║  Kernel vulnerable: \$(uname -r)               ║"
echo "  ║  CVE-2026-31431 Copy Fail Lab                ║"
echo "  ╚═══════════════════════════════════════════════╝"
echo ""

# Login como student (sin privilegios) para simular el escenario LPE
exec /bin/su - student
INITEOF
chmod +x "$INITRAMFS_DIR/init"

echo -e "${CYAN}[5/5] Empaquetando initramfs...${NC}"
# Crear /usr/bin/su real setuid-root para el PoC
SUBIN="$(command -v su || true)"
if [ -n "$SUBIN" ]; then
  mkdir -p "$INITRAMFS_DIR/usr/bin"
  cp -L "$SUBIN" "$INITRAMFS_DIR/usr/bin/su"
  chown 0:0 "$INITRAMFS_DIR/usr/bin/su" 2>/dev/null || true
  chmod 4755 "$INITRAMFS_DIR/usr/bin/su"

  # Copiar librerías dinámicas requeridas por su
  ldd "$SUBIN" | awk '/=> \// {print $3} /^\// {print $1}' | while read -r lib; do
    dest="$INITRAMFS_DIR$lib"
    mkdir -p "$(dirname "$dest")"
    cp -L "$lib" "$dest"
  done

  # Copiar dynamic loader
  ldd "$SUBIN" | grep -o '/lib[^ ]*/ld-linux[^ ]*' | while read -r ld; do
    dest="$INITRAMFS_DIR$ld"
    mkdir -p "$(dirname "$dest")"
    cp -L "$ld" "$dest"
  done

  # Copiar PAM básico para que su pueda iniciar
  mkdir -p "$INITRAMFS_DIR/etc/pam.d" "$INITRAMFS_DIR/lib/x86_64-linux-gnu/security"
  cp -a /etc/pam.d/su "$INITRAMFS_DIR/etc/pam.d/su" 2>/dev/null || true
  cp -a /etc/pam.d/common-* "$INITRAMFS_DIR/etc/pam.d/" 2>/dev/null || true
  cp -a /lib/x86_64-linux-gnu/security/*.so "$INITRAMFS_DIR/lib/x86_64-linux-gnu/security/" 2>/dev/null || true
fi

# Copiar exploit para Hito 2 dentro de la VM
if [ -f "$WORKSPACE_ROOT/exploit/copy_fail_exp.py" ]; then
  cp "$WORKSPACE_ROOT/exploit/copy_fail_exp.py" "$INITRAMFS_DIR/home/student/copy_fail_exp.py"
  chmod 755 "$INITRAMFS_DIR/home/student/copy_fail_exp.py"
  chown 1001:1001 "$INITRAMFS_DIR/home/student/copy_fail_exp.py" 2>/dev/null || true
fi

# Copiar Python 3 para ejecutar el PoC dentro de la VM
PYBIN="$(command -v python3 || true)"
if [ -n "$PYBIN" ]; then
  mkdir -p "$INITRAMFS_DIR/usr/bin" "$INITRAMFS_DIR/usr/lib" "$INITRAMFS_DIR/lib" "$INITRAMFS_DIR/lib64"

  cp "$PYBIN" "$INITRAMFS_DIR/usr/bin/python3"
  ln -sf /usr/bin/python3 "$INITRAMFS_DIR/bin/python3"

  # Copiar librerías dinámicas requeridas por python3
  ldd "$PYBIN" | awk '/=> \// {print $3} /^\// {print $1}' | while read -r lib; do
    dest="$INITRAMFS_DIR$lib"
    mkdir -p "$(dirname "$dest")"
    cp -L "$lib" "$dest"
  done

  # Copiar el dynamic loader si aparece en ldd
  ldd "$PYBIN" | grep -o '/lib[^ ]*/ld-linux[^ ]*' | while read -r ld; do
    dest="$INITRAMFS_DIR$ld"
    mkdir -p "$(dirname "$dest")"
    cp -L "$ld" "$dest"
  done

  # Copiar stdlib de Python, necesaria para socket, zlib, os, etc.
  PYVER="$($PYBIN - <<'PYV'
import sys
print(f"python{sys.version_info.major}.{sys.version_info.minor}")
PYV
)"
  if [ -d "/usr/lib/$PYVER" ]; then
    mkdir -p "$INITRAMFS_DIR/usr/lib"
    cp -a "/usr/lib/$PYVER" "$INITRAMFS_DIR/usr/lib/"
  fi
fi

cd "$INITRAMFS_DIR"
find . | cpio -o -H newc 2>/dev/null | gzip > "$BUILD_DIR/initramfs.cpio.gz"

SIZE=$(du -sh "$BUILD_DIR/initramfs.cpio.gz" | cut -f1)
echo -e "${GREEN}✓ initramfs listo (${SIZE}) en: $BUILD_DIR/initramfs.cpio.gz${NC}"
echo -e "${GREEN}  STUDENT_ID: ${STUDENT_ID}${NC}"
