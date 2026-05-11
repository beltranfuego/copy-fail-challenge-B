# Copy Fail Lab — CVE-2026-31431 (v2)

Devcontainer reproducible para experimentar con la vulnerabilidad **Copy Fail**
(CVE-2026-31431) en un kernel Linux 6.12 controlado dentro de QEMU.

Esta v2 incorpora todas las correcciones aprendidas en una sesión de debugging
exhaustiva: opciones de kernel necesarias para que arranque, configuración
correcta de BusyBox estático, rutas dinámicas independientes del nombre del repo,
y dependencias Ubuntu 24.04 corregidas.

---

## Inicio rápido para el estudiante

1. Abre un Codespace desde este repo.
   ```bash
   #CONFIGURACION DE EJEMPLO!!!!!!!!!!!
   apt update
   apt install gh
   
   gh api user --jq '"\(.name) → \(.email // .login)"'
   
   git config --global user.name "Jonathan E. Tito O."
   git config --global user.email "jonathantito@users.noreply.github.com"
   git config --global --add safe.directory /workspaces/copy-fail-challenge-1
   make setup
   ```
3. Configura tu identidad git:
   ```bash
   git config --global user.name "Tu Nombre"
   git config --global user.email "tu@correo.com"
   ```
4. Ejecuta:
   ```bash
   make setup    # descarga kernel + arma rootfs (~5 min)
   make qemu     # arranca la VM vulnerable
   ```

Para salir de QEMU: `Ctrl+A` luego `X`.

---

## Configuración inicial del docente (una sola vez)

### 1. Subir este repo a GitHub

```bash
cd copyfail-v2
git init && git add -A && git commit -m "initial"
git branch -M main
gh repo create TU-ORG/copy-fail-lab --public --source=. --push
```

### 2. Marcarlo como Template

GitHub → tu repo → Settings → marcar `Template repository`.

### 3. Editar `.devcontainer/devcontainer.json`

Cambia el valor `KERNEL_REPO`:
```json
"KERNEL_REPO": "TU-ORG/copy-fail-lab"
```

Commit y push.

### 4. Disparar el workflow del kernel

GitHub → Actions → `Build Vulnerable Kernel` → Run workflow.
Tarda ~25 min en los servidores de GitHub (no en tu Codespace).
Al terminar crea un Release con el `bzImage_vuln` listo para descarga.

### 5. Verificar

Tu repo → Releases → debe aparecer `kernel-v6.12-vuln` con tres archivos
adjuntos. Los estudiantes ahora pueden hacer `make setup` y descarga en 2 min.

---

## Estructura del repo

```
.
├── .devcontainer/
│   ├── Dockerfile             ← Ubuntu 24.04 + deps verificadas
│   └── devcontainer.json      ← sin rutas hardcodeadas
├── .github/workflows/
│   └── build-kernel.yml       ← compila kernel y crea Release
├── scripts/
│   ├── 00_welcome.sh
│   ├── 01_fetch_kernel.sh     ← descarga del Release
│   ├── 02_build_kernel.sh     ← fallback: compila desde fuente
│   ├── 03_build_rootfs.sh     ← BusyBox estático + initramfs
│   └── 04_run_qemu.sh
├── Makefile
└── README.md
```

---

## Comandos disponibles

| Comando | Acción |
|---|---|
| `make setup` | Descarga kernel + arma rootfs (~5 min) |
| `make qemu` | Arranca la VM vulnerable |
| `make info` | Muestra el estado del ambiente |
| `make rootfs` | Reconstruye solo el initramfs |
| `make fetch-kernel` | Solo descarga el bzImage del Release |
| `make build-kernel` | Compila kernel desde fuente (~25 min) |
| `make clean` | Borra builds (mantiene fuentes) |
| `make clean-all` | Borra todo |

---

## Recursos del CVE

- Write-up técnico: https://xint.io/blog/copy-fail-linux-distributions
- Sitio del CVE: https://copy.fail
- PoC oficial: https://github.com/theori-io/copy-fail-CVE-2026-31431

---

## Lecciones aprendidas (referencia para futuras versiones)

Esta v2 incorpora los siguientes fixes respecto a la v1:

- `hexdump` → `bsdextrautils` en Ubuntu 24.04
- `bzip2` agregado al Dockerfile (lo necesita BusyBox)
- Eliminado el `mounts` con ruta hardcodeada en `devcontainer.json`
- Todos los scripts detectan workspace con `SCRIPT_DIR` dinámico
- Kernel: agregadas opciones críticas `BINFMT_ELF`, `BINFMT_SCRIPT`, `RD_GZIP`
- Kernel: agregada dep `CRYPTO_AEAD` antes de `CRYPTO_AUTHENCESN`
- BusyBox: reemplazado `scripts/config` (no existe) por `sed`
- BusyBox: eliminado `olddefconfig` (no existe en BusyBox)
- BusyBox: deshabilitado `CONFIG_TC` (rompe compilación con kernels nuevos)
- BusyBox: forzado `CONFIG_STATIC=y` y verificado con `file`
- Workflow Actions: greps de verificación con `|| echo`, tolerantes


HISTORY

    1  apt update
    2  apt install gh
    3  gh api user --jq '"\(.name) → \(.email // .login)"'
    4  git config --global user.name "ARTHUR BELTRAN"
    5  git config --global user.email "arbeltranhe@uide.edu.ec"
    6  git config --global --add safe.directory /workspaces/copy-fail-challenge-1
    7  make setup
    8  make qemu
    9  apt update
   10  apt install -y file
   11  make rootfs
   12  make qemu
   13  grep -n "tmp\|proc\|sysfs\|devtmpfs\|student\|su" scripts/03_build_rootfs.sh
   14  nano scripts/03_build_rootfs.sh
   15  apt update
   16  apt install -y nano
   17  nano scripts/03_build_rootfs.sh
   18  python3 - <<'PY'
from pathlib import Path

p = Path("scripts/03_build_rootfs.sh")
s = p.read_text()

old = "mount -t tmpfs none /tmp"
new = "mount -t tmpfs none /tmp\nchmod 1777 /tmp"

if new not in s:
    s = s.replace(old, new)

p.write_text(s)
print("Listo: agregado chmod 1777 /tmp después del mount de /tmp")
PY

   19  grep -n "tmpfs none /tmp\|chmod 1777 /tmp\|proc\|student" scripts/03_build_rootfs.sh
   20  make rootfs
   21  make qemu
   22  grep -E "CONFIG_CRYPTO_USER_API|CONFIG_CRYPTO_USER_API_AEAD|CONFIG_CRYPTO_AUTHENC|CONFIG_CRYPTO_AUTHENCESN|CONFIG_CRYPTO_g
   23  cd /workspaces/copy-fail-challenge-B/kernel/linux
   24  ./scripts/config --enable CRYPTO_AUTHENCESN
   25  ./scripts/config --enable IKCONFIG
   26  ./scripts/config --enable IKCONFIG_PROC
   27  make olddefconfig
   28  grep -E "CONFIG_CRYPTO_AUTHENCESN|CONFIG_IKCONFIG|CONFIG_IKCONFIG_PROC" .config
   29  grep -R "AUTHENCESN" crypto/ Kconfig .config 2>/dev/null
   30  grep -R "authenc" crypto/ | head -40
   31  find crypto -iname "*auth*"
   32  grep -R "CRYPTO_AUTHENC" crypto/ -n | head -40
   33  cd /workspaces/copy-fail-challenge-B
   34  make build-kernel
   35  make rootfs
   36  make qemu
   37  cd /workspaces/copy-fail-challenge-B
   38  grep -R "bzImage\|qemu-system\|-kernel" -n Makefile scripts/
   39  find . -name "bzImage*" -type f -ls
   40  ls -lh kernel/linux/arch/x86/boot/bzImage 2>/dev/null
   41  ls -lh bzImage* 2>/dev/null
   42  ls -lh build/* 2>/dev/null
   43  cd /workspaces/copy-fail-challenge-B/kernel/linux
   44  ./scripts/extract-ikconfig ../build/bzImage_vuln | grep -E "CONFIG_IKCONFIG|CONFIG_IKCONFIG_PROC|CONFIG_CRYPTO_AUTHENC|CO"
   45  cd /workspaces/copy-fail-challenge-B/kernel/linux
   46  ./scripts/config --enable IKCONFIG
   47  ./scripts/config --enable IKCONFIG_PROC
   48  ./scripts/config --enable CRYPTO_AEAD
   49  ./scripts/config --enable CRYPTO_AUTHENC
   50  ./scripts/config --enable CRYPTO_USER_API
   51  ./scripts/config --enable CRYPTO_USER_API_AEAD
   52  ./scripts/config --enable CRYPTO_USER_API_SKCIPHER
   53  ./scripts/config --enable CRYPTO_CBC
   54  ./scripts/config --enable CRYPTO_AES
   55  ./scripts/config --enable CRYPTO_SHA256
   56  make olddefconfig
   57  grep -E "CONFIG_IKCONFIG|CONFIG_IKCONFIG_PROC|CONFIG_CRYPTO_AUTHENC|CONFIG_CRYPTO_USER_API|CONFIG_CRYPTO_USER_API_AEAD|COg
   58  make -j"$(nproc)" bzImage
   59  cp arch/x86/boot/bzImage ../build/bzImage_vuln
   60  ./scripts/extract-ikconfig ../build/bzImage_vuln | grep -E "CONFIG_IKCONFIG|CONFIG_IKCONFIG_PROC|CONFIG_CRYPTO_AUTHENC|CO"
   61  cd /workspaces/copy-fail-challenge-B
   62  make rootfs
   63  make qemu
   64  mkdir -p evidence
   65  cat > evidence/hito1_vuln_confirmed.txt
   66  cat evidence/hito1_vuln_confirmed.txt
   67  git add evidence/hito1_vuln_confirmed.txt scripts/03_build_rootfs.sh kernel/linux/.config
   68  git commit -m "hito-1: kernel vulnerable confirmado - $(date +%Y-%m-%dT%H:%M)"
   69  git tag -a hito-1 -m "Kernel vulnerable corriendo y AF_ALG AEAD confirmado"
   70  git push origin main --tags
   71  make qemu
   72  cd /workspaces/copy-fail-challenge-B
   73  mkdir -p exploit
   74  curl -L https://copy.fail/exp -o exploit/copy_fail_exp.py
   75  ls -l exploit/copy_fail_exp.py
   76  head exploit/copy_fail_exp.py
   77  apt update
   78  apt install -y curl
   79  curl -L https://copy.fail/exp -o exploit/copy_fail_exp.py
   80  grep -n "cpio\|INITRAMFS_DIR\|home/student" scripts/03_build_rootfs.sh
   81  python3 - <<'PY'
from pathlib import Path

p = Path("scripts/03_build_rootfs.sh")
s = p.read_text()

insert = '''\
# Copiar exploit para Hito 2 dentro de la VM
if [ -f "$REPO_ROOT/exploit/copy_fail_exp.py" ]; then
  cp "$REPO_ROOT/exploit/copy_fail_exp.py" "$INITRAMFS_DIR/home/student/copy_fail_exp.py"
  chmod 755 "$INITRAMFS_DIR/home/student/copy_fail_exp.py"
  chown 1001:1001 "$INITRAMFS_DIR/home/student/copy_fail_exp.py" 2>/dev/null || true
fi

'''

if "copy_fail_exp.py" not in s:
    marker = "( cd \"$INITRAMFS_DIR\" && find ."
    if marker in s:
        s = s.replace(marker, insert + marker)
    else:
        raise SystemExit("No encontré el marcador del cpio. Pásame grep -n 'cpio\\|find .' scripts/03_build_rootfs.sh")
    p.write_text(s)
    print("Listo: exploit agregado al rootfs antes de crear el cpio.")
else:
    print("Ya había una referencia a copy_fail_exp.py en el script.")
PY

   82  python3 - <<'PY'
from pathlib import Path

p = Path("scripts/03_build_rootfs.sh")
s = p.read_text()

insert = '''\
# Copiar exploit para Hito 2 dentro de la VM
if [ -f "$REPO_ROOT/exploit/copy_fail_exp.py" ]; then
  cp "$REPO_ROOT/exploit/copy_fail_exp.py" "$INITRAMFS_DIR/home/student/copy_fail_exp.py"
  chmod 755 "$INITRAMFS_DIR/home/student/copy_fail_exp.py"
  chown 1001:1001 "$INITRAMFS_DIR/home/student/copy_fail_exp.py" 2>/dev/null || true
fi

'''

if "copy_fail_exp.py" not in s:
    marker = "( cd \"$INITRAMFS_DIR\" && find ."
    if marker in s:
        s = s.replace(marker, insert + marker)
    else:
        raise SystemExit("No encontré el marcador del cpio. Pásame grep -n 'cpio\\|find .' scripts/03_build_rootfs.sh")
    p.write_text(s)
    print("Listo: exploit agregado al rootfs antes de crear el cpio.")
else:
    print("Ya había una referencia a copy_fail_exp.py en el script.")
PY

   83  grep -n "cpio\|find \.\|INITRAMFS_DIR\|ROOTFS\|home/student" scripts/03_build_rootfs.sh
   84  find . | cpio -o -H newc 2>/dev/null | gzip > "$BUILD_DIR/initramfs.cpio.gz"
   85  jobs
   86  kill %1
   87  jobs
   88  bash -n scripts/03_build_rootfs.sh && echo "script OK" || echo "script con error"
   89  grep -n "copy_fail_exp.py\|cd \"\$INITRAMFS_DIR\"\|cpio" scripts/03_build_rootfs.sh
   90  python3 - <<'PY'
from pathlib import Path

p = Path("scripts/03_build_rootfs.sh")
s = p.read_text()

insert = '''\
# Copiar exploit para Hito 2 dentro de la VM
if [ -f "$WORKSPACE_ROOT/exploit/copy_fail_exp.py" ]; then
  cp "$WORKSPACE_ROOT/exploit/copy_fail_exp.py" "$INITRAMFS_DIR/home/student/copy_fail_exp.py"
  chmod 755 "$INITRAMFS_DIR/home/student/copy_fail_exp.py"
  chown 1001:1001 "$INITRAMFS_DIR/home/student/copy_fail_exp.py" 2>/dev/null || true
fi

'''

marker = 'cd "$INITRAMFS_DIR"'

if "copy_fail_exp.py" not in s:
    s = s.replace(marker, insert + marker)
    p.write_text(s)
    print("Listo: agregado copy_fail_exp.py al rootfs antes del cpio.")
else:
    print("Ya existe copy_fail_exp.py en el script.")
PY

   91  grep -n "copy_fail_exp.py\|cd \"\$INITRAMFS_DIR\"\|cpio" scripts/03_build_rootfs.sh
   92  mkdir -p exploit
   93  curl -L https://copy.fail/exp -o exploit/copy_fail_exp.py
   94  ls -l exploit/copy_fail_exp.py
   95  head exploit/copy_fail_exp.py
   96  apt update
   97  apt install -y curl
   98  curl -L https://copy.fail/exp -o exploit/copy_fail_exp.py
   99  bash -n scripts/03_build_rootfs.sh && echo "script OK"
  100  make rootfs
  101  make qemu
  102  which python3
  103  python3 --version
  104  cd /workspaces/copy-fail-challenge-B
  105  python3 - <<'PY'
from pathlib import Path

p = Path("scripts/03_build_rootfs.sh")
s = p.read_text()

insert = r'''# Copiar Python 3 para ejecutar el PoC dentro de la VM
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

'''

marker = 'cd "$INITRAMFS_DIR"'

if "Copiar Python 3 para ejecutar el PoC" not in s:
    s = s.replace(marker, insert + marker)
    p.write_text(s)
    print("Listo: bloque de Python agregado al rootfs.")
else:
    print("El bloque de Python ya existía.")
PY

  106  grep -n "Copiar Python\|copy_fail_exp.py\|cd \"\$INITRAMFS_DIR\"\|cpio" scripts/03_build_rootfs.sh
  107  bash -n scripts/03_build_rootfs.sh && echo "script OK"
  108  make rootfs
  109  make qemu
  110  cd /workspaces/copy-fail-challenge-B
  111  grep -n "CONFIG_SU\|FEATURE_SU" kernel/busybox/.config
  112  python3 - <<'PY'
from pathlib import Path

p = Path("scripts/03_build_rootfs.sh")
s = p.read_text()

insert = r'''# Crear /usr/bin/su como binario setuid-root para el PoC
mkdir -p "$INITRAMFS_DIR/usr/bin"
if [ -f "$INITRAMFS_DIR/bin/busybox" ]; then
  cp "$INITRAMFS_DIR/bin/busybox" "$INITRAMFS_DIR/usr/bin/su"
  chown 0:0 "$INITRAMFS_DIR/usr/bin/su" 2>/dev/null || true
  chmod 4755 "$INITRAMFS_DIR/usr/bin/su"
fi

'''

marker = '# Copiar exploit para Hito 2 dentro de la VM'

if "Crear /usr/bin/su como binario setuid-root para el PoC" not in s:
    s = s.replace(marker, insert + marker)
    p.write_text(s)
    print("Listo: agregado /usr/bin/su setuid-root al rootfs.")
else:
    print("El bloque de /usr/bin/su ya existía.")
PY

  113  grep -n "usr/bin/su\|copy_fail_exp.py\|Copiar Python" scripts/03_build_rootfs.sh
  114  g.system("su")
  115  python3 - <<'PY'
from pathlib import Path

p = Path("scripts/03_build_rootfs.sh")
s = p.read_text()

old = "chmod 1777 /tmp"
new = "chmod 1777 /tmp\nexport PATH=/usr/bin:/bin:/sbin:/usr/sbin"

if "export PATH=/usr/bin:/bin:/sbin:/usr/sbin" not in s:
    s = s.replace(old, new)
    p.write_text(s)
    print("Listo: PATH actualizado.")
else:
    print("PATH ya estaba actualizado.")
PY

  116  grep -n "export PATH\|usr/bin/su" scripts/03_build_rootfs.sh
  117  bash -n scripts/03_build_rootfs.sh && echo "script OK"
  118  make rootfs
  119  make qemu
  120  cd /workspaces/copy-fail-challenge-B
  121  grep -n 'g.system' exploit/copy_fail_exp.py
  122  python3 - <<'PY'
from pathlib import Path

p = Path("exploit/copy_fail_exp.py")
s = p.read_text()

s = s.replace('g.system("su")', 'g.system("/usr/bin/su")')

p.write_text(s)
print("Listo: exploit ahora ejecuta /usr/bin/su directamente.")
PY

  123  tail -3 exploit/copy_fail_exp.py
  124  make rootfs
  125  make qemu
  126  python3 - <<'PY'
from pathlib import Path
import re

p = Path("scripts/03_build_rootfs.sh")
s = p.read_text()

new_block = r'''# Crear /usr/bin/su real setuid-root para el PoC
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

'''

pattern = r'# Crear /usr/bin/su como binario setuid-root para el PoC\n.*?fi\n\n# Copiar exploit para Hito 2 dentro de la VM'

if re.search(pattern, s, flags=re.S):
    s = re.sub(pattern, new_block + '# Copiar exploit para Hito 2 dentro de la VM', s, flags=re.S)
else:
    marker = '# Copiar exploit para Hito 2 dentro de la VM'
    if new_block not in s:
        s = s.replace(marker, new_block + marker)

p.write_text(s)
print("Listo: /usr/bin/su ahora se copia desde el host con librerías.")
PY

  127  grep -n "Crear /usr/bin/su\|SUBIN\|copy_fail_exp.py\|Copiar Python" scripts/03_build_rootfs.sh
  128  tail -3 exploit/copy_fail_exp.py
  129  bash -n scripts/03_build_rootfs.sh && echo "script OK"
  130  make rootfs
  131  make qemu
  132  cd /workspaces/copy-fail-challenge-B
  133  python3 - <<'PY'
from pathlib import Path
p = Path("exploit/copy_fail_exp.py")
s = p.read_text()
s = s.replace('g.system("su")', 'g.system("/usr/bin/su")')
p.write_text(s)
print("exploit del host corregido")
PY

  134  tail -2 exploit/copy_fail_exp.py
  135  make rootfs
  136  make qemu
  137  history