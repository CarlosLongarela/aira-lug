# AIra Lug: cerebro digital local

## AVISO IMPORTANTE
**Software y concepto aún en fase de desarrollo.**

**AIra Lug** es un cerebro digital personal: una [eira o aira](https://gl.wikipedia.org/wiki/Eira), el espacio gallego donde se reunía, se trabajaba y se separaba el grano valioso, unido a [Lug](https://es.wikipedia.org/wiki/Lug), figura celta asociada a las artes, las ciencias y las habilidades. Un lugar para convertir información dispersa en conocimiento útil, conectado y propio.

Esta guía prepara AIra Lug como un vault de Obsidian versionado en un repositorio privado, con búsqueda híbrida local mediante QMD y acceso de un agente Hermes mediante dos MCP: QMD para consulta y un servidor de archivos con acceso de escritura limitado al vault.

El vault Markdown es la fuente de verdad. El índice y los embeddings de QMD son locales en cada equipo y no se suben al repositorio.

## Arquitectura y criterio de actualización

| Componente | Función | Acceso de Hermes |
| --- | --- | --- |
| Obsidian + vault | Crear, leer y organizar los Markdown | No directo |
| GitHub privado + Git | Historial y sincronización | Commit/push mediante script controlado |
| QMD CLI | Índice, embeddings y mantenimiento | Solo ejecución local del script |
| MCP QMD | Búsqueda y lectura de notas | Consulta, sin escritura |
| MCP de archivos | Crear o modificar Markdown del vault | Escritura, limitado a la carpeta del vault |
| LM Studio | Modelos locales y servidor local opcional | Proveedor local, si Hermes lo admite |
| Hermes | Orquestación, modelos locales o externos | Usa ambos MCP con permisos separados |

La actualización es **por eventos con reconciliación diaria**. Es preferible a un cron frecuente porque actualiza pronto tras recibir o confirmar cambios, sin reindexar repetidamente cuando no ha ocurrido nada. Aun así, los hooks no ven una nota editada pero todavía no confirmada; la reconciliación diaria y `scripts/qmd-refresh` cubren ese caso y cualquier fallo transitorio.

Los hooks incluidos cubren:

- `post-merge`: cambios recibidos por merge o `git pull` que haga merge/fast-forward.
- `post-rewrite`: `git rebase` y `git commit --amend`.
- `post-checkout`: únicamente cuando se cambia de rama, no al recuperar un archivo.
- `post-commit`: cambios locales confirmados, incluidos los de Obsidian Git.

Git documenta estos puntos de extensión y permite versionarlos con `core.hooksPath`. [Documentación de hooks de Git](https://git-scm.com/docs/githooks)

## 1. Instalar Git y crear el repositorio privado

Instala Git desde [git-scm.com/downloads](https://git-scm.com/downloads). En Linux, instala el paquete `git` con el gestor de paquetes de la distribución si lo prefieres. Comprueba la instalación:

```sh
git --version
```

Configura la identidad de los commits una sola vez en cada equipo. Sustituye los valores:

```sh
git config --global user.name "Tu nombre"
git config --global user.email "tu-correo@ejemplo.com"
git config --global --list
```

El correo de Git determina cómo GitHub asocia los commits a la cuenta. [GitHub: configurar Git](https://docs.github.com/en/get-started/git-basics/set-up-git)

En GitHub, crea un repositorio nuevo y selecciona **Private**. No inicialices el repositorio con README, `.gitignore` ni licencia: el primer contenido se creará localmente. La visibilidad privada restringe quién puede acceder al repositorio. [GitHub: repositorios privados](https://docs.github.com/en/repositories/creating-and-managing-repositories/about-repositories)

### Autenticación recomendada: SSH

Usa una clave SSH protegida con frase de paso en cada equipo. Conserva la clave privada solo en ese equipo y añade únicamente su clave pública a GitHub.

Primero, comprueba si ya tienes una clave que quieras reutilizar:

```sh
ls -al ~/.ssh
```

Si no existe `id_ed25519` e `id_ed25519.pub`, genera una clave nueva. Sustituye el correo por el de tu cuenta de GitHub y acepta la ruta propuesta; elige una frase de paso segura:

```sh
ssh-keygen -t ed25519 -C "tu-correo@ejemplo.com"
```

En macOS y Linux, inicia el agente y carga la clave:

```sh
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

En macOS, para guardar la frase de paso en el llavero, usa en su lugar:

```sh
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

En Windows, abre PowerShell como administrador una vez y activa el servicio; después, en una ventana normal de PowerShell, añade la clave:

```powershell
Get-Service -Name ssh-agent | Set-Service -StartupType Manual
Start-Service ssh-agent
ssh-add $env:USERPROFILE\.ssh\id_ed25519
```

Si Git para Windows siguiera solicitando la frase de paso, configúralo para usar OpenSSH de Windows:

```powershell
git config --global core.sshCommand "C:/Windows/System32/OpenSSH/ssh.exe"
```

Muestra y copia **solo** la clave pública:

```sh
cat ~/.ssh/id_ed25519.pub
```

En GitHub, abre **Settings → SSH and GPG keys → New SSH key**, elige el tipo **Authentication**, pon un título identificable —por ejemplo, `Portátil personal`—, pega la clave pública y guarda. No compartas ni subas nunca el archivo sin `.pub`. [Generar y cargar claves SSH](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) · [Añadir la clave pública a GitHub](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account)

Comprueba la conexión:

```sh
ssh -T git@github.com
```

En la primera conexión, comprueba la huella mostrada contra las [huellas SSH publicadas por GitHub](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints) antes de aceptar. El mensaje final debe incluir tu nombre de usuario; que el comando termine con código 1 es normal. [Probar la conexión SSH](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection)

En GitHub copia la URL SSH del repositorio (`git@github.com:TU_USUARIO/TU_REPOSITORIO.git`) y ejecuta:

```sh
mkdir mi-vault
cd mi-vault
git init
git branch -M main
git remote add origin git@github.com:TU_USUARIO/TU_REPOSITORIO.git
```

Si ya configuraste el remoto por HTTPS, cámbialo sin volver a clonar:

```sh
git remote set-url origin git@github.com:TU_USUARIO/TU_REPOSITORIO.git
git remote -v
```

## 2. Instalar LM Studio y ejecutar un modelo local

Descarga LM Studio desde [su página oficial](https://lmstudio.ai/download). En Linux, la descarga ofrece AppImage y `.deb`; en Windows y macOS usa el instalador de la página. Verifica antes los [requisitos de sistema](https://lmstudio.ai/docs/app/system-requirements): en particular, macOS requiere Apple Silicon y macOS 14 o posterior; en Windows x64 se requiere AVX2.

En LM Studio:

1. Descarga un modelo que se ajuste a la RAM/VRAM del equipo.
2. Cárgalo y comprueba una conversación local.
3. Si Hermes puede usar un endpoint compatible con OpenAI, inicia el servidor local desde LM Studio y configura Hermes con la URL, el modelo y el puerto que muestre esa aplicación. No expongas ese servidor a Internet sin autenticación y control de red.

LM Studio también ofrece una API local compatible con OpenAI y puede funcionar sin conexión una vez descargados los modelos. [Documentación de LM Studio](https://lmstudio.ai/docs/developer) · [Funcionamiento sin conexión](https://lmstudio.ai/docs/app/offline)

## 3. Crear el vault de Obsidian

Instala Obsidian desde [obsidian.md/download](https://obsidian.md/download). Abre la aplicación, elige **Create new vault** y selecciona la carpeta `mi-vault` creada en el paso 1. Crea una nota, por ejemplo `Inicio.md`.

Crea este `.gitignore` en la raíz del vault:

```gitignore
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.DS_Store
Thumbs.db
```

No ignores `.obsidian` completo si quieres compartir la configuración del vault; revisa antes qué ajustes o plugins contienen datos sensibles.

Haz el primer envío:

```sh
git add .
git commit -m "Inicializa el vault"
git push -u origin main
```

En los demás equipos, clona el repositorio privado y ábrelo con **Open folder as vault** en Obsidian:

```sh
git clone git@github.com:TU_USUARIO/TU_REPOSITORIO.git mi-vault
cd mi-vault
```

## 4. Configurar Obsidian Git

En Obsidian ve a **Settings → Community plugins**, desactiva el modo restringido, busca **Obsidian Git** e instálalo. La referencia oficial del complemento es [community.obsidian.md/plugins/obsidian-git](https://community.obsidian.md/plugins/obsidian-git).

Configuración inicial recomendada:

1. Activa **Pull updates on startup**.
2. Activa **Auto commit-and-sync after stopping file edits** o usa el comando **Obsidian Git: Commit-and-sync** de forma consciente.
3. Empieza con un intervalo moderado, por ejemplo 15 minutos; no uses un intervalo muy corto.
4. En cada equipo prueba un commit y push manual antes de activar la automatización.

El plugin puede hacer commit, pull y push, y dispone de auto-pull al iniciar. Si recibe un conflicto, resuélvelo antes de seguir editando. [Documentación del plugin](https://github.com/Vinzent03/obsidian-git)

## 5. Instalar y preparar QMD

QMD requiere Node.js 22 o superior. Instala una versión LTS desde [nodejs.org/download](https://nodejs.org/en/download) y comprueba:

```sh
node --version
npm --version
```

Instala QMD y registra el vault como colección. Ejecuta estos comandos desde la raíz del vault:

```sh
npm install -g @tobilu/qmd
qmd --version
qmd collection add "$PWD" --name vault
qmd update
qmd embed
qmd status
```

En PowerShell, si `$PWD` no se interpreta como ruta por tu versión de terminal, usa:

```powershell
qmd collection add (Get-Location).Path --name vault
```

La primera ejecución descarga modelos de búsqueda locales. `qmd update` detecta documentos nuevos, modificados y eliminados; `qmd embed` genera los vectores pendientes. Si cambias el modelo de embeddings, reconstruye los vectores con `qmd embed -f`. [QMD: instalación y embeddings](https://github.com/tobi/qmd#requirements) · [Colecciones y actualización](https://github.com/tobi/qmd#configuring-indexyml)

Para un vault principalmente en español, valida la calidad de búsqueda con notas reales antes de cambiar de modelo. No es necesario usar LM Studio para que QMD genere sus embeddings: QMD gestiona sus propios modelos locales por defecto.

## 6. Registrar los hooks versionables

Copia las carpetas `.githooks` y `scripts` que acompañan a este README a la raíz del vault. Desde esa raíz, ejecuta:

```sh
git config core.hooksPath "$(pwd)/.githooks"
chmod +x .githooks/* scripts/*
git add .githooks scripts README.md .gitignore
git commit -m "Añade la automatización del índice QMD"
git push
```

En Windows ejecuta esos comandos desde **Git Bash**, incluido `chmod`; Git para Windows lo instala habitualmente. En PowerShell, configura la ruta absoluta así y deja que Git invoque los scripts con su shell:

```powershell
git config core.hooksPath "$(Get-Location)\.githooks"
```

`core.hooksPath` es una configuración local, así que hay que repetirla tras cada clon. Los scripts usan un directorio de bloqueo dentro de `.git` para no ejecutar dos actualizaciones de QMD a la vez. Si ya hay una ejecución, el nuevo evento se omite sin bloquear Git; la siguiente operación o la reconciliación lo recuperará.

Prueba:

```sh
printf "\nPrueba de índice\n" >> Inicio.md
git add Inicio.md
git commit -m "Prueba de QMD"
qmd status
```

## 7. Añadir QMD como MCP de consulta

Configura el cliente MCP que use Hermes con este proceso local:

```json
{
  "command": "qmd",
  "args": ["mcp"]
}
```

No lo declares como herramienta de escritura. QMD expone búsqueda, lectura y estado a través de MCP; la actualización y los embeddings se realizan por CLI. [Configuración MCP de QMD](https://github.com/tobi/qmd/blob/main/skills/qmd/references/mcp-setup.md)

Antes de conectarlo a Hermes, arranca `qmd mcp` en una terminal para comprobar que el binario está disponible. Si Hermes se ejecuta sin interfaz o como servicio, asegúrate de que su entorno tiene el mismo `PATH` que contiene `qmd`.

## 8. Añadir el MCP de archivos con permiso mínimo

Configura el servidor MCP de archivos de Hermes con una única raíz permitida: la carpeta absoluta del vault. Debe permitir crear y modificar `*.md`, pero no leer o escribir fuera de ella. No concedas acceso al directorio de inicio, a otras carpetas de trabajo, ni a los archivos de configuración que contengan claves.

Los nombres, el formato de configuración y las capacidades exactas dependen del servidor MCP de archivos y de la versión de Hermes que instales. Compruébalos en su documentación antes de copiar una configuración: no hay una configuración genérica segura que pueda afirmarse para todas las distribuciones de Hermes.

## 9. Configurar Hermes Agent

En Hermes crea un agente con:

- El MCP de QMD como fuente de **consulta y búsqueda**.
- El MCP de archivos limitado al vault como única vía de **escritura**.
- Un proveedor local mediante LM Studio, si la versión de Hermes admite endpoint OpenAI-compatible, o un proveedor externo configurado con su clave mediante el mecanismo que documente Hermes.

No incluyo un fichero de configuración de Hermes porque no se ha proporcionado su versión ni su documentación oficial y no sería correcto inventar su esquema. Mantén las claves de proveedores externos fuera del vault y fuera de Git; usa las variables de entorno o almacén de secretos que indique Hermes.

Instrucción operativa que debe seguir la skill de escritura de Hermes:

1. Consultar QMD antes de redactar cuando necesite contexto.
2. Escribir el Markdown en el vault mediante el MCP de archivos.
3. Ejecutar `scripts/hermes-write-and-sync RUTA/nota.md "Mensaje de commit"` desde la raíz del vault.
4. Si el script falla, no reintentar con `push --force`; informar del error y dejar la resolución de conflicto para revisión.

El script solo añade y confirma la ruta Markdown indicada. Primero actualiza QMD y sus embeddings —y falla si QMD no está disponible—, después intenta el push normal. Dos invocaciones de Hermes se serializan mediante un bloqueo. No puede coordinar a la fuerza con un usuario o con Obsidian Git que ya esté modificando el repositorio: en ese caso falla de forma segura y debe reintentarse cuando el repositorio esté estable.

## 10. Reconciliación de respaldo

Programa **una vez al día** `scripts/qmd-refresh` en cada equipo. Es una red de seguridad, no el mecanismo principal.

- **Windows:** crea una tarea en el Programador de tareas que ejecute Git Bash con `-lc 'cd /ruta/al/vault && scripts/qmd-refresh'`.
- **macOS/Linux:** crea un `cron` o temporizador de usuario que ejecute `cd /ruta/al/vault && ./scripts/qmd-refresh`.

Antes de automatizarlo, ejecuta manualmente el mismo comando y confirma `qmd status`. Si el equipo está apagado, no hace falta recuperar ejecuciones perdidas: la próxima ejecución reconciliará el estado actual del vault.

## Operación habitual y diagnóstico

| Situación | Acción |
| --- | --- |
| Editas una nota y Obsidian Git la confirma | `post-commit` actualiza QMD. |
| Recibes notas desde otro equipo | `post-merge` o `post-rewrite` actualiza QMD. |
| Cambias de rama | `post-checkout` actualiza QMD. |
| Hermes crea una nota | El script actualiza QMD, confirma esa nota y hace push. |
| QMD parece desactualizado | Ejecuta `scripts/qmd-refresh` y luego `qmd status`. |
| Hay conflicto de Git | Resuélvelo, confirma el resultado y ejecuta `scripts/qmd-refresh`. |
| El bloqueo queda tras un cierre forzoso | Comprueba que no hay una actualización activa y elimina manualmente `.git/qmd-refresh.lock`. |

Nunca subas claves API, archivos `.env`, tokens o datos que no deban residir en GitHub. Un repositorio privado limita el acceso, pero no sustituye una política de secretos ni copias de seguridad verificadas.
