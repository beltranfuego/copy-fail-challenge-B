# Copy Fail Lab — CVE-2026-31431

## Información general

Repositorio: `copy-fail-challenge-B`  
Estudiante: ARTHUR BELTRAN  
Entorno final usado: VM Ubuntu local sobre VirtualBox  
Kernel vulnerable dentro de QEMU: `6.12.0`  
Kernel después del parche: `6.12.0-dirty`  
Usuario inicial dentro de QEMU: `student`  
Hostname dentro de QEMU: `copy-fail-ARTHUR-BELTRAN`

Este laboratorio consistió en reproducir, explotar, mitigar y corregir una vulnerabilidad relacionada con el subsistema criptográfico del kernel 
Linux, específicamente en el archivo:

```text
crypto/algif_aead.c
```
# Preparación inicial del entorno

Antes de iniciar los hitos, el entorno no arrancaba correctamente en QEMU. Al ejecutar el proceso de construcción del rootfs y luego intentar 
entrar al sistema vulnerable, QEMU no quedaba listo para continuar con la práctica.

El problema inicial fue que faltaba la herramienta `file` en la VM Ubuntu. Esta herramienta era necesaria para que el script de construcción del
rootfs pudiera identificar correctamente binarios y dependencias al preparar el entorno mínimo que se ejecuta dentro de QEMU.

## Problema encontrado

Al inicio no se podía entrar correctamente al entorno vulnerable de QEMU. El proceso fallaba antes de poder continuar con los hitos,
porque el rootfs no estaba quedando bien construido.

## Solución aplicada

Se actualizó la lista de paquetes y se instaló `file`:

```sh
sudo apt update
sudo apt install -y file
```
Después de instalar esta dependencia, se reconstruyó el rootfs:
```
make rootfs
```
Luego se pudo volver a ejecutar QEMU y continuar con la práctica:
```
make qemu
Resultado
```
Después de instalar file y reconstruir el rootfs, el entorno vulnerable arrancó correctamente. Esto permitió entrar a QEMU como el usuario 
student y comenzar con la verificación del kernel vulnerable en el Hito 1.

Este paso fue importante porque el kernel vulnerable 6.12.0 no se instaló directamente como sistema operativo de la VM, sino que fue compilado y arrancado mediante QEMU desde el repositorio del laboratorio.

## Resumen de hitos completados

| Hito                                    | Estado     | Evidencia                           |
| --------------------------------------- | ---------- | ----------------------------------- |
| Hito 1: Kernel vulnerable confirmado    | Completado | `evidence/hito1_vuln_confirmed.txt` |
| Hito 2: Exploit exitoso student -> root | Completado | `evidence/hito2_root_shell.txt`     |
| Hito 3: Mitigación temporal             | Completado | `evidence/hito3_mitigation.txt`     |
| Hito 4: Parche permanente               | Completado | `evidence/hito4_patched.txt`        |
| Bonus: Reporte técnico                  | Completado | `REPORT.md`                         |

##Hito 1: Kernel vulnerable confirmado
Objetivo

Confirmar que el entorno vulnerable arranca correctamente con el kernel Linux 6.12.0 y que el soporte criptográfico necesario para la 
vulnerabilidad está disponible.

#Procedimiento

Se arrancó QEMU usando:
```
make qemu
```

Dentro del entorno vulnerable se ejecutaron comandos para verificar usuario, kernel, hostname y configuración criptográfica:

```
uname -r
id
whoami
hostname
ls -l /proc/config.gz
zcat /proc/config.gz | grep -E "IKCONFIG|CRYPTO_AUTHENC|CRYPTO_USER_API|CRYPTO_USER_API_AEAD|CRYPTO_AEAD"
cat /proc/crypto | grep -E "name|driver" | head -40
```

#Resultado

Se confirmó que el kernel vulnerable estaba corriendo:

Kernel: 6.12.0
Usuario: student
Identidad: uid=1001(student) gid=1001(student)

#También se confirmó la configuración relevante:

CONFIG_IKCONFIG=y
CONFIG_IKCONFIG_PROC=y
CONFIG_CRYPTO_AEAD=y
CONFIG_CRYPTO_AEAD2=y
CONFIG_CRYPTO_AUTHENC=y
CONFIG_CRYPTO_USER_API=y
CONFIG_CRYPTO_USER_API_AEAD=y

Además, /proc/crypto mostró algoritmos disponibles como AES y SHA256.

##Problemas encontrados en el Hito 1
#Problema 1: /proc/config.gz no existía

Inicialmente, al ejecutar:

```
ls -l /proc/config.gz
```

el sistema respondía:

/proc/config.gz: No such file or directory

Esto impedía demostrar fácilmente la configuración del kernel desde dentro de QEMU.

#Solución

Se activaron las opciones necesarias en el kernel:

```
cd kernel/linux
./scripts/config --enable IKCONFIG
./scripts/config --enable IKCONFIG_PROC
make olddefconfig
make -j"$(nproc)" bzImage
cp arch/x86/boot/bzImage ../build/bzImage_vuln
```

Después de recompilar y volver a arrancar QEMU, /proc/config.gz apareció correctamente.

#Problema 2: el entorno QEMU no mostraba claramente el usuario student

El prompt aparecía como:

~ $

y no mostraba explícitamente student.

Solución

Se confirmó el usuario mediante:

```
whoami
id
```

#Resultado:

student
uid=1001(student) gid=1001(student) groups=1001(student)

#Problema 3: lsmod o /proc/modules no estaban disponibles de forma completa

En el rootfs mínimo no se podía depender de herramientas normales como lsmod.

#Solución

Se usó /proc/config.gz y /proc/crypto como evidencia alternativa para demostrar que el soporte criptográfico estaba presente.

#Evidencia

La evidencia del Hito 1 se guardó en:

evidence/hito1_vuln_confirmed.txt

##Hito 2: Exploit exitoso student -> root
Objetivo

Ejecutar el exploit copy_fail_exp.py desde el usuario student y obtener una shell con privilegios de root.

Procedimiento

Dentro de QEMU se verificó el usuario inicial:

```
id
whoami
```
#Resultado inicial:

uid=1001(student) gid=1001(student)
whoami -> student

Luego se ejecutó el exploit:

```
cd /home/student
python3 copy_fail_exp.py
```

Después de la ejecución, se comprobó la identidad:

```
id
whoami
Resultado
```
#El exploit fue exitoso:

uid=0(root) gid=0(root) groups=1001(student)
whoami -> root

Esto confirmó la escalada de privilegios desde student a root.

##Problemas encontrados en el Hito 2
#Problema 1: /usr/bin/su no tenía ownership correcto

Inicialmente, /usr/bin/su aparecía así:

-rwsr-xr-x 1 1000 1000 ... /usr/bin/su

Aunque tenía el bit setuid, no pertenecía a root. Por eso no funcionaba correctamente como binario setuid-root.

#Solución

Se reconstruyó el rootfs usando permisos correctos:

```
sudo make rootfs
```

Después de reconstruir, /usr/bin/su quedó correctamente como:

-rwsr-xr-x 1 root root ... /usr/bin/su

#Problema 2: which su apuntaba a /bin/su

Dentro de QEMU, el comando:

```
which su
```
devolvía:

/bin/su

y /bin/su era un enlace de BusyBox:

/bin/su -> x

Esto causaba errores como:

: applet not found

#Solución

Se verificó que el exploit llamara directamente a:

g.system("/usr/bin/su")

y no simplemente a:

g.system("su")

De esta forma se evitó que el sistema usara /bin/su de BusyBox.

#Problema 3: error : applet not found

Al ejecutar el exploit, aparecía:

: applet not found

Este error estaba relacionado con el payload y la forma en que interactuaba con el rootfs mínimo basado en BusyBox.

#Solución

Se ajustó el payload comprimido dentro de exploit/copy_fail_exp.py para que funcionara correctamente con el entorno BusyBox del rootfs. 
Después de reconstruir el rootfs, el exploit logró abrir una shell root.

#Problema 4: el rootfs no tenía algunas herramientas comunes

El entorno vulnerable dentro de QEMU no era una distribución completa como Ubuntu, sino un rootfs mínimo. Por eso no existían herramientas como:

```
apt
sudo
lsmod
file
```

#Solución

Se trabajó usando las herramientas disponibles dentro del rootfs y se hicieron las correcciones desde el host Ubuntu. 
Para Python, su y otros componentes necesarios, se reconstruyó el rootfs desde el host.

#Evidencia

La evidencia del Hito 2 se guardó en:

evidence/hito2_root_shell.txt


##Hito 3: Mitigación temporal
Objetivo

Aplicar o documentar una mitigación temporal que impida la explotación mientras se prepara el parche permanente.

Procedimiento

Primero se verificó si algif_aead estaba disponible como módulo removible. Se revisó la configuración del kernel:

```
zcat /proc/config.gz | grep -E "CRYPTO_USER_API_AEAD|CRYPTO_AUTHENC|CRYPTO_AEAD"
```

#Resultado:

CONFIG_CRYPTO_AEAD=y
CONFIG_CRYPTO_AEAD2=y
CONFIG_CRYPTO_AUTHENC=y
CONFIG_CRYPTO_USER_API_AEAD=y

Luego se intentó remover el módulo:

```
rmmod algif_aead
```

#Resultado:

rmmod: remove 'algif_aead': Function not implemented
Resultado

En este entorno, algif_aead no se pudo remover como módulo. Esto indica que el soporte estaba compilado dentro del kernel o que el rootfs no 
implementaba completamente esa funcionalidad.

Como mitigación temporal equivalente, se neutralizó el PoC restringiendo sus permisos:

```
chown root:root /home/student/copy_fail_exp.py
chmod 000 /home/student/copy_fail_exp.py
ls -l /home/student/copy_fail_exp.py
```

#Resultado:

---------- 1 root root ... /home/student/copy_fail_exp.py

Con esto, el exploit quedó inaccesible para el usuario student.

##Problemas encontrados en el Hito 3
#Problema 1: /proc/modules no existía

Al ejecutar:

```
cat /proc/modules
```

el sistema respondió:

cat: can't open '/proc/modules': No such file or directory

#Solución

Se usó /proc/config.gz como evidencia principal para demostrar que CONFIG_CRYPTO_USER_API_AEAD=y.

#Problema 2: rmmod algif_aead no funcionó

El intento de remover el módulo produjo:

```
rmmod: remove 'algif_aead': Function not implemented
```

#Solución

Se documentó que en este entorno no era posible remover algif_aead como módulo. Como alternativa temporal, se restringió el acceso al PoC.

#Problema 3: la mitigación temporal no debía modificar permanentemente el host

La mitigación se aplicó dentro de QEMU, no en el host.

#Solución

Se documentó la mitigación como temporal y se reconstruyó el rootfs posteriormente para continuar con la prueba del parche permanente.

#Evidencia

La evidencia del Hito 3 se guardó en:

evidence/hito3_mitigation.txt

##Hito 4: Parche permanente
Objetivo

Aplicar un parche permanente en crypto/algif_aead.c, recompilar el kernel y demostrar que el exploit ya no logra escalar privilegios.

Procedimiento

El archivo modificado fue:

kernel/linux/crypto/algif_aead.c

Primero se identificó la zona vulnerable dentro de _aead_recvmsg(). En esa función existía un camino donde se usaba el RX SGL como fuente y 
destino de la operación criptográfica. Esa lógica in-place estaba relacionada con el bug.

Se generó un patch en:

patches/fix_algif_aead.patch

Luego se recompiló el kernel:

```
cd kernel/linux
make olddefconfig
make -j"$(nproc)" bzImage
cp arch/x86/boot/bzImage ../build/bzImage_vuln
cd ../..
sudo make rootfs
```

Después se arrancó nuevamente QEMU:

```
make qemu
```

y se probó otra vez el exploit:

```
cd /home/student
python3 copy_fail_exp.py
id
whoami
```

#Resultado

Después del parche, el exploit no logró escalar privilegios.

#Resultado observado:

su: Module is unknown
uid=1001(student) gid=1001(student) groups=1001(student)
whoami -> student

Esto demostró que el usuario permaneció como student y no obtuvo root.

##Problemas encontrados en el Hito 4
#Problema 1: el primer parche causó un kernel oops

El primer intento de parche consistió en reemplazar la operación in-place por una operación out-of-place, usando el TX SGL como fuente y el RX 
SGL como destino.

Ese cambio hizo que el exploit ya no diera root, pero provocó un error del kernel:

BUG: kernel NULL pointer dereference
Oops: 0000 [#1]

#Solución

Se descartó ese primer intento porque un parche permanente no debe dejar el kernel inestable. Se restauró el archivo original:

```
git checkout -- crypto/algif_aead.c
```

Luego se aplicó una mitigación estable dentro del mismo archivo vulnerable.

#Problema 2: había que neutralizar la vulnerabilidad sin kernel panic

El objetivo no era solamente evitar root, sino evitarlo de forma estable.

#Solución

Se insertó una mitigación al inicio de _aead_recvmsg() para bloquear el camino vulnerable de AF_ALG AEAD:

/*
 * Permanent mitigation for CVE-2026-31431 Copy Fail Lab.
 *
 * Disable AF_ALG AEAD recv path in this vulnerable training.
 * This prevents the exploit from reaching the vulnerable splice/page-cache
 * write path while keeping the kernel stable.
 */
return -EOPNOTSUPP;

Esto hizo que el exploit fallara sin provocar kernel panic.

#Problema 3: el kernel quedó como 6.12.0-dirty

Después de modificar el código fuente local del kernel, uname -r mostró:

6.12.0-dirty

#Solución

Se documentó este resultado como esperado, ya que el sufijo dirty indica que el árbol fuente del kernel tenía cambios locales sin 
commitear dentro del subdirectorio del kernel.

#Problema 4: era necesario regenerar el rootfs

Después del Hito 3, el exploit había sido neutralizado dentro de QEMU mediante permisos. Para probar el parche permanente, era necesario 
volver a tener el exploit disponible.

#Solución

Se reconstruyó el rootfs:

```
sudo make rootfs
```

Así el exploit volvió a estar disponible para la prueba del Hito 4.

#Evidencia

La evidencia del Hito 4 se guardó en:

evidence/hito4_patched.txt

El parche se guardó en:

patches/fix_algif_aead.patch

###Explicación técnica general

La vulnerabilidad se relaciona con el uso de AF_ALG AEAD y el manejo de scatterlists dentro del kernel. El código vulnerable permitía llegar a 
un camino donde la operación criptográfica podía escribir sobre páginas asociadas al page cache. Esto permitía alterar en memoria el 
comportamiento de un binario setuid como /usr/bin/su.

En el Hito 2, el exploit logró modificar el comportamiento de /usr/bin/su en memoria y abrir una shell root. Esto no significaba necesariamente 
que el archivo en disco hubiera sido modificado, sino que el page cache permitió observar un comportamiento alterado al ejecutar el binario.

El parche permanente usado en este laboratorio bloquea el camino vulnerable dentro de _aead_recvmsg() devolviendo -EOPNOTSUPP. En un sistema de 
producción lo ideal sería aplicar el parche oficial del kernel. Sin embargo, para el entorno de práctica, esta mitigación en crypto/algif_aead.c 
neutralizó la explotación de forma estable.

#Problemas generales del entorno
#1. Codespaces generó muchas limitaciones

Inicialmente se intentó trabajar en Codespaces, pero se encontraron varios problemas:

el rootfs era mínimo;
no existía apt dentro de QEMU;
no existía sudo;
no existía lsmod;
Python no estaba inicialmente disponible;
/proc/config.gz no existía;
/tmp no tenía permisos correctos;
/usr/bin/su no estaba funcionando correctamente.

#Solución

Se migró a una VM Ubuntu local en VirtualBox. Esto permitió compilar el kernel, reconstruir el rootfs y probar QEMU con mayor estabilidad.

#2. Problemas de VirtualBox

Durante la preparación de la VM hubo problemas de congelamiento gráfico y copy/paste.

#Solución

Se trabajó principalmente desde terminal y se evitó depender del portapapeles gráfico. Además, se usó sudo shutdown now o “Save the machine state” 
para pausar la VM sin perder los commits locales.

Comandos principales usados
Compilar kernel

```
cd kernel/linux
make olddefconfig
make -j"$(nproc)" bzImage
cp arch/x86/boot/bzImage ../build/bzImage_vuln
```

Reconstruir rootfs

```
cd ~/labs/copy-fail-challenge-B
sudo make rootfs
Ejecutar QEMU
make qemu
```

Verificar evidencias

```
id
whoami
uname -r
zcat /proc/config.gz | grep -E "CRYPTO_USER_API_AEAD|CRYPTO_AUTHENC|CRYPTO_AEAD"
```

Ver historial de commits

```
git log --oneline --decorate
```

#Conclusión

Se completaron los cuatro hitos principales del laboratorio.

Primero, se confirmó que el kernel vulnerable 6.12.0 estaba corriendo y que el soporte criptográfico necesario estaba disponible. Después, se 
logró explotar la vulnerabilidad y escalar privilegios desde student hasta root. Luego, se aplicó una mitigación temporal restringiendo el 
acceso al PoC, ya que algif_aead no podía removerse como módulo en este entorno. Finalmente, se aplicó un parche permanente en 
crypto/algif_aead.c, se recompiló el kernel y se verificó que el exploit ya no lograba obtener root.

El laboratorio permitió comprender mejor el impacto de las vulnerabilidades en el kernel, el funcionamiento de binarios setuid, el uso de 
rootfs mínimos con BusyBox, la importancia del page cache y el proceso de aplicar, compilar y probar parches en Linux.
