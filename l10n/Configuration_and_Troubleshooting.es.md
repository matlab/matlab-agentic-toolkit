<!--
Source English Markdown:
- File: ./Configuration_and_Troubleshooting.md
- Branch: main
- Commit: 645cf259dedf8b012f89fdb7006ad7c1afa33e3e
-->

# Configuración y solución de problemas

<p align="center">
  <a href="../Configuration_and_Troubleshooting.md">English</a> •
  Español •
  <a href="Configuration_and_Troubleshooting.ja.md">日本語</a> •
  <a href="Configuration_and_Troubleshooting.ko.md">한국어</a> •
  <a href="Configuration_and_Troubleshooting.zh-cn.md">简体中文</a>
</p>

Esta página muestra cómo configurar MATLAB&reg; Agentic Toolkit. Para obtener una visión general de MATLAB Agentic Toolkit, consulte el [README](README.es.md).

## Requisitos

- MATLAB R2021a o posterior
- Agente de codificación de IA que admita servidores MCP y skills. Los agentes compatibles se configuran automáticamente. De lo contrario, consulte la documentación de su agente para configurar manualmente el servidor MCP e instalar skills. Los agentes compatibles incluyen:
  - Claude Code  
  - GitHub&reg; Copilot  
  - OpenAI&reg; Codex  
  - Gemini&trade; CLI  
  - Amp

---

## Instalar desde archivos locales (equipo sin conexión)

Para instalar MATLAB Agentic Toolkit en un entorno sin conexión o aislado, primero descargue estos artefactos en un equipo con acceso a Internet y transfiéralos al equipo de destino o a una ubicación compartida.

| Artefacto | Dónde obtenerlo |
|----------|----------------|
| Binario de MCP Server | [Última versión de MATLAB MCP Server](https://github.com/matlab/matlab-mcp-server/releases/latest) — descargue el binario para su plataforma (por ejemplo, `matlab-mcp-server-macos-arm64`, `matlab-mcp-server-windows-x64.exe`). |
| Toolbox de MCP Server | [Última versión de MATLAB MCP Server](https://github.com/matlab/matlab-mcp-server/releases/latest) — descargue `MATLABMCPServerToolbox.mltbx`. |
| Instalador de Agentic Toolkit | [Última versión de Simulink Agentic Toolkit](https://github.com/matlab/simulink-agentic-toolkit/releases/latest) — descargue `agenticToolkitInstaller.mltbx`. |
| MATLAB Agentic Toolkit | Clone o descargue desde [GitHub](https://github.com/matlab/matlab-agentic-toolkit). |
| Simulink Agentic Toolkit | Clone o descargue desde [GitHub](https://github.com/matlab/simulink-agentic-toolkit). Solo es necesario al instalar Simulink Agentic Toolkit.|

Después de descargar estos artefactos, abra `agenticToolkitInstaller.mltbx` en MATLAB para instalar el complemento del instalador.
En MATLAB, ejecute el comando `setupAgenticToolkit` en la ventana de comandos con estos argumentos de nombre-valor.

| Argumento | Valor |
|----------|-----------------|
| `MCPServerLocation` | Ruta a la descarga del binario de MCP Server |
| `MCPToolboxLocation` | Ruta a la descarga de la toolbox de MATLAB (`.mltbx`) |
| `MATLABAgenticToolkitLocation` | Ruta al clon del repositorio de MATLAB Agentic Toolkit |
| `SimulinkAgenticToolkitLocation` | Ruta al clon del repositorio de Simulink Agentic Toolkit |

El instalador descarga cualquier artefacto que no proporcione localmente. Para impedir el acceso a Internet y notificar un error si un artefacto no está disponible, establezca `Offline=true`. Por ejemplo, utilice este comando para instalar MATLAB Agentic Toolkit desde archivos locales.

```matlab
setupAgenticToolkit("install", Offline=true,  ...
    MCPServerLocation="/shared/agentic-toolkits/bin/matlab-mcp-server-linux-x64", ...
    MCPToolboxLocation="/shared/agentic-toolkits/toolboxes/MATLABMCPServerToolbox.mltbx", ...
    MATLABAgenticToolkitLocation="/shared/agentic-toolkits/matlab-agentic-toolkit")
```

---

## Instalar MATLAB usando su agente

Si no tiene MATLAB instalado, puede instalar MATLAB con su agente de IA siguiendo estos pasos.
1) Instale las skills de MATLAB Agentic Toolkit siguiendo los pasos en [Agregar solo skills](#adding-skills-only).
2) Solicite a su agente que instale MATLAB usando la skill `matlab-install-products`.

Después de instalar MATLAB, puede completar la configuración de MATLAB Agentic Toolkit siguiendo las instrucciones en [Instalador de Agentic Toolkit](README.es.md#instalar-matlab-agentic-toolkit) para instalar automáticamente MATLAB MCP Server, o instalando y configurando manualmente MATLAB MCP Server.

---

## Instalar y configurar MCP Server

Para instalar y configurar manualmente MCP Server en lugar de utilizar la configuración automatizada, consulte las instrucciones en el repositorio de GitHub de [MATLAB MCP Server](https://github.com/matlab/matlab-mcp-core-server). Después de instalar MCP Server, apunte la configuración MCP de su agente al binario instalado. Consulte esta tabla para conocer las ubicaciones de los archivos de configuración, o consulte la documentación de su agente.

| Plataforma | Configuración MCP | Notas específicas de la plataforma |
|----------|------------------|-------------------|
| Claude Code | `~/.claude.json` | Utilice `claude mcp add` para configurar. |
| GitHub Copilot | `mcp.json` del perfil de usuario de VS Code | Vuelva a cargar VS Code después de que finalice la configuración. |
| OpenAI Codex | `~/.codex/config.toml` | Después de la configuración, puede editar dos ajustes de configuración en la sección `[mcp_servers.matlab]` de `~/.codex/config.toml`: 1) Establezca `tool_timeout_sec = 600` para aumentar el tiempo de espera de la herramienta para operaciones más prolongadas de MATLAB, como conjuntos de pruebas y simulaciones. Auméntelo aún más para tareas de muy larga duración. 2) Establezca `env_vars = ['WINDIR']` en Windows&reg; para que Simulink&reg; funcione, ya que Codex elimina las variables de entorno de los subprocesos de MCP Server de forma predeterminada. |
| Gemini CLI | `~/.gemini/settings.json` | Inicie una nueva sesión de Gemini después de la configuración. |
| Amp | `~/.config/amp/settings.json` | Si tiene reglas `amp.mcpPermissions` que bloquean servidores MCP, agregue una regla de permiso para el servidor de MATLAB. |

---

## Deshabilitar la recopilación de datos

MATLAB MCP Server recopila información totalmente anónima sobre su uso del servidor y la envía a MathWorks&reg;. Esta recopilación de datos ayuda a MathWorks a mejorar los productos y está activada de forma predeterminada. Para excluirse de la recopilación de datos, configure el toolkit con la opción `DisableTelemetry` establecida en `true` ejecutando este comando en MATLAB:

```matlab
setupAgenticToolkit("configure", DisableTelemetry=true)
```

Este comando excluye a todos los agentes configurados de la recopilación de datos. Este ajuste de configuración se conserva cuando actualiza a una nueva versión del toolkit con `setupAgenticToolkit("update")`. Si vuelve a configurar el toolkit para su(s) agente(s) ejecutando `setupAgenticToolkit("configure")`, incluya `DisableTelemetry=true` nuevamente para mantener deshabilitada la recopilación de datos.

---

<a id="adding-skills-only"></a>
## Agregar solo skills

Si ya tiene MATLAB MCP Server, solo necesita skills. Las skills se organizan en carpetas dentro de `skills-catalog/`, denominadas grupos de skills. Debe instalar el grupo de skills `matlab-core`. Para obtener experiencia adicional en dominios específicos, puede instalar por separado otros grupos de skills específicos. Instale solo las skills necesarias para permitir que su agente active las skills de forma fiable. Para garantizar la carga de una skill específica en su flujo de trabajo, también puede activar manualmente la skill con su nombre.

Para obtener más información sobre skills y grupos de skills, consulte el [README de `skills-catalog/`](skills-catalog/README.es.md).

### Claude Code

Cada grupo de skills se proporciona como un plugin de Claude Code. Para agregar un grupo de skills, primero agregue el marketplace e instale el grupo de skills `matlab-core`.

```bash
claude plugin marketplace add "https://github.com/matlab/matlab-agentic-toolkit"
claude plugin install matlab-core@matlab-agentic-toolkit
```

Después de instalar el grupo de skills `matlab-core`, utilice el mismo patrón con el nombre de directorio del grupo para instalar un grupo de skills específico.

```bash
claude plugin install <group-name>@matlab-agentic-toolkit
```

Por ejemplo, para agregar skills de procesamiento de señales y comunicaciones inalámbricas:

```bash
claude plugin install signal-processing@matlab-agentic-toolkit
claude plugin install wireless-communications@matlab-agentic-toolkit
```

Elija su ámbito preferido (por proyecto, por usuario o global) cuando se le solicite. Su configuración MCP existente no se modifica.

### GitHub Copilot, OpenAI Codex, Gemini CLI

La mayoría de los demás agentes de IA descubren skills desde `~/.agents/skills/`. Para agregar skills a su agente, debe configurar enlaces simbólicos desde la carpeta `~/.agents/skills/` a los grupos de skills individuales. Primero, clone el toolkit.

```bash
git clone https://github.com/matlab/matlab-agentic-toolkit.git
```

Después de clonar el toolkit, cree enlaces simbólicos para cada grupo que desee. Reemplace `/path/to/matlab-agentic-toolkit` con la ruta real al clon de su toolkit, y liste los grupos que necesite. Por ejemplo, para instalar `matlab-core` y `signal-processing`, utilice estos comandos.

```bash
mkdir -p ~/.agents/skills
for group in matlab-core signal-processing; do
  for skill in /path/to/matlab-agentic-toolkit/skills-catalog/$group/*/; do
    ln -s "$skill" ~/.agents/skills/$(basename "$skill")
  done
done
```

Alternativamente, para Gemini, puede agregar skills instalando el toolkit como una extensión de Gemini CLI.
  ```bash
 gemini extensions install https://github.com/matlab/matlab-agentic-toolkit
  ```

### Amp

Amp lee las skills desde las rutas listadas en `~/.config/amp/settings.json`. Primero, clone el toolkit.

```bash
git clone https://github.com/matlab/matlab-agentic-toolkit.git
```

Después de clonar el toolkit, agregue una entrada de ruta `skills-catalog/<group>` para cada grupo que desee.

```json
{
  "amp.skills.path": [
    "/path/to/matlab-agentic-toolkit/skills-catalog/matlab-core",
    "/path/to/matlab-agentic-toolkit/skills-catalog/signal-processing"
  ]
}
```

---

## Verificación

### Comprobar que las skills están cargadas

Si su agente muestra las skills o plugins cargados en su interfaz (por ejemplo, el comando `/skills` de Claude Code), confirme que las skills de MATLAB Agentic Toolkit aparecen en la lista.

### Pruébelo

Pregunte a su agente:

```
What version of MATLAB is running? List the installed toolboxes.
```

El agente llama a `detect_matlab_toolboxes` mediante MCP e informa de la versión de MATLAB y las toolboxes disponibles.

### Más ejemplos

```
Write a function that computes the moving average of a signal, then generate unit tests for it.
```

```
Review the file myScript.m for code quality issues and suggest improvements.
```

```
Create a plain-text Live Script that demonstrates curve fitting with sample data.
```
---

## Configuración por proyecto

Cuando instala MATLAB Agentic Toolkit con la configuración automatizada del [README](README.es.md) de nivel superior, el toolkit se configura globalmente. Las herramientas y skills de MATLAB están disponibles en todas las sesiones independientemente del proyecto que abra.

También puede configurar MCP Server a nivel de proyecto. Esto le permite limitar el ámbito de sus herramientas y skills solo a los proyectos que las necesitan. Cuando la configuración se confirma en el control de versiones, también ayuda a sus equipos, ya que cualquier persona que clone el repositorio obtiene la conexión con MATLAB automáticamente (siempre que tenga instalado el binario de MCP Server).

### Archivos de plantilla

El directorio [`templates/`](../templates/) contiene configuraciones iniciales para cada plataforma. Copie la plantilla correspondiente en la carpeta raíz de su proyecto, actualice las rutas y confírmela en el control de versiones.

| Plataforma | Plantilla | Ubicación del proyecto |
|----------|----------|-----------------|
| GitHub Copilot | `templates/vscode-mcp.json` | `.vscode/mcp.json` |
| Amp | `templates/amp-settings.json` | `.amp/settings.json` |
| OpenAI Codex | `templates/codex-mcp.json` | `.codex/config.json` en la raíz del proyecto |

> **Claude Code** utiliza `claude plugin install` con selección de ámbito (por proyecto, por usuario o global) en lugar de un archivo de configuración de proyecto. Consulte [Agregar solo skills](#adding-skills-only).

### Ejemplo: GitHub Copilot

```bash
mkdir -p .vscode
cp /path/to/matlab-agentic-toolkit/templates/vscode-mcp.json .vscode/mcp.json
```

A continuación, edite `.vscode/mcp.json` para reemplazar las rutas de marcador de posición con las rutas reales del binario de MCP Server y de la raíz de MATLAB.

> **Nota:** Las configuraciones por proyecto contienen rutas absolutas al binario de MCP Server y a la raíz de MATLAB, que varían según el equipo. Si su equipo utiliza distintas plataformas de sistema operativo o ubicaciones de instalación, considere documentar las rutas esperadas en el README de su proyecto.

---

## Solución de problemas

| Problema | Causa probable | Solución |
|---------|-------------|-----|
| La configuración no encuentra MATLAB | Ubicación de instalación no estándar | Proporcione la ruta cuando se le solicite |
| La descarga de MCP Server falla | Red/proxy/firewall | Descargue manualmente desde las [versiones de GitHub](https://github.com/matlab/matlab-mcp-core-server/releases), colóquelo en `~/.matlab/agentic-toolkits/bin/`, vuelva a ejecutar la configuración |
| macOS bloquea el binario de MCP Server | Cuarentena de Gatekeeper | La configuración gestiona esto automáticamente. Si sigue bloqueado (MDM), vaya a Ajustes del Sistema > Privacidad y Seguridad > Permitir de todos modos |
| El agente no lista las skills de MATLAB | Plugin no instalado o skills no enlazadas | Vuelva a ejecutar la configuración; para Claude Code, pruebe `claude plugin install matlab-core@matlab-agentic-toolkit` |
| Las herramientas MCP no logran conectarse | Falta el binario de MCP Server o la ruta en la configuración es incorrecta | Vuelva a ejecutar la configuración inicial para regenerar la configuración. Verifique que el binario existe: `~/.matlab/agentic-toolkits/bin/matlab-mcp-server --version` |
| `evaluate_matlab_code` devuelve errores | Ruta `--matlab-root` incorrecta, problema de licencia o fallo al iniciar MATLAB | Verifique que MATLAB puede iniciarse: `<matlab-root>/bin/matlab -nodesktop -r "disp('ok'),quit"`. Compruebe el estado de la licencia. Vuelva a ejecutar la configuración para corregir la ruta de la raíz de MATLAB |
| Las llamadas de herramientas de Codex agotan el tiempo de espera | Tiempo de espera predeterminado de la herramienta demasiado corto para MATLAB | Agregue `tool_timeout_sec = 600` (o superior) a `[mcp_servers.matlab]` en `~/.codex/config.toml` |
| Simulink falla en Codex en Windows | Falta la variable de entorno `WINDIR` | Agregue `env_vars = ['WINDIR']` a `[mcp_servers.matlab]` en `~/.codex/config.toml` |
| Las skills no se cargan automáticamente | Demasiadas skills instaladas | Consulte [Las skills no se cargan automáticamente](#skills-not-auto-loading) a continuación |

---

<a id="skills-not-auto-loading"></a>
### Las skills no se cargan automáticamente

Los agentes tienen contexto limitado. Cuando instala muchos grupos de skills, algunas skills pueden pasarse por alto o recortarse del contexto y su agente podría no activar automáticamente la skill correcta para una tarea determinada.

#### Soluciones recomendadas

1. Instale solo los grupos de skills que necesita: Esta es la solución recomendada. Utilice el instalador basado en MATLAB (`setupAgenticToolkit("install")`) para seleccionar los grupos de skills específicos que sean relevantes para su trabajo. Cuantas menos skills haya instaladas, más fiable será la identificación y activación de la skill correcta por parte del agente.

2. Active las skills manualmente por nombre: Si sabe qué skill necesita, actívela directamente.
   - En Claude Code, utilice el comando de barra (por ejemplo, `/matlab-write-tests`).
   - En otros agentes, solicítela explícitamente: "Use the matlab-write-tests skill to...".

3. Elimine los grupos de skills que no utiliza: Si instaló todos los grupos mediante la configuración basada en el agente, elimine los que no necesita.
   - Claude Code: `claude plugin remove <group-name>@matlab-agentic-toolkit`.
   - Copilot, Codex, Gemini CLI: Elimine los enlaces simbólicos correspondientes de `~/.agents/skills/`.
   - Amp: Elimine la ruta del grupo de `amp.skills.path` en `~/.config/amp/settings.json`.

Estamos explorando activamente soluciones más robustas para mejorar el descubrimiento y la carga automática de skills cuando hay muchas skills instaladas.

---

## Soporte y contribuciones
MathWorks le anima a utilizar este repositorio y proporcionar comentarios. Las solicitudes de extracción no están habilitadas en este repositorio. Para solicitar soporte técnico o enviar una solicitud de mejora, [cree una incidencia en GitHub](https://github.com/matlab/matlab-agentic-toolkit/issues) o [póngase en contacto con el soporte técnico](https://www.mathworks.com/support/contact_us.html).

----

Copyright 2026 The MathWorks, Inc.

----
