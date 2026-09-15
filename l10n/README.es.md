<!--
Source English Markdown:
- File: ./README.md
- Branch: main
- Commit: 645cf259dedf8b012f89fdb7006ad7c1afa33e3e
-->

# MATLAB Agentic Toolkit

<p align="center">
  <a href="../README.md">English</a> •
  Español •
  <a href="README.ja.md">日本語</a> •
  <a href="README.ko.md">한국어</a> •
  <a href="README.zh-cn.md">简体中文</a>
</p>

[![Latest Release](https://img.shields.io/github/v/release/matlab/matlab-agentic-toolkit?cacheSeconds=1800)](https://github.com/matlab/matlab-agentic-toolkit/releases/latest)
[![Release Date](https://img.shields.io/github/release-date/matlab/matlab-agentic-toolkit?cacheSeconds=1800)](https://github.com/matlab/matlab-agentic-toolkit/releases/latest)

MATLAB&reg; Agentic Toolkit permite usar agentes de IA con MATLAB proporcionando al agente de IA el conocimiento y el contexto necesarios para trabajar eficientemente con MATLAB y sus toolboxes. Use este toolkit para proporcionar funcionalidades de MATLAB de confianza a su agente. Este toolkit puede evitar que su agente de IA alucine funciones de toolboxes, pase por alto funcionalidades nuevas y pierda tiempo con pasos adicionales que los usuarios experimentados de MATLAB omitirían.

Use este toolkit para:

- Conectar su agente de IA a MATLAB. Este toolkit lo hace instalando automáticamente el [MATLAB MCP Server](https://github.com/matlab/matlab-mcp-server). Luego puede usar su agente para escribir código idiomático, generar y ejecutar pruebas, diagnosticar errores, compilar aplicaciones y más.

- Proporcionar conocimientos seleccionados, llamados skills, a su agente. Estas skills equipan a su agente con conocimiento de flujos de trabajo, convenciones y buenas prácticas de MATLAB, a la vez que minimizan el consumo de tokens.

> [!Note]
> Para usar agentes de IA solamente con Simulink&reg;, instale el [Simulink Agentic Toolkit](https://github.com/matlab/simulink-agentic-toolkit). Para instalar ambos toolkits, use el [Agentic Toolkit Installer](#instalar-matlab-agentic-toolkit).

## Requisitos

* MATLAB R2021a o posterior
* Agente de IA que admita servidores MCP y skills. Los agentes compatibles se configuran automáticamente. De lo contrario, consulte la documentación de su agente para configurar manualmente el servidor MCP e instalar skills. Los agentes compatibles incluyen:
    - Claude Code
    - GitHub&reg; Copilot
    - OpenAI&reg; Codex
    - Gemini&trade; CLI
    - Amp

---
## Introduccion a MATLAB Agentic Toolkit

Estos pasos muestran cómo usar MATLAB Agentic Toolkit para instalar MATLAB MCP Server y agregar skills a su agente.

> Nota: Para obtener instrucciones sobre la instalación desde archivos locales, la instalación en un entorno sin conexión, las opciones de configuración de este toolkit, notas específicas de la plataforma, pasos de verificación, resolución de problemas y la configuración manual sin el instalador, consulte [Configuration and Troubleshooting](../Configuration_and_Troubleshooting.md). Si ya tiene instalado el servidor MCP y solo necesita agregar skills, consulte [Adding Skills Only](../Configuration_and_Troubleshooting.md#adding-skills-only).

### Instalar MATLAB Agentic Toolkit

Siga estos pasos para configurar MATLAB Agentic Toolkit.

1. Para descargar el instalador, haga clic en [agenticToolkitInstaller.mltbx](https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx).
2. Abra el archivo descargado con MATLAB para instalar el complemento del instalador.
3. En MATLAB, ejecute este comando.

```matlab
setupAgenticToolkit("install")
```

4. Instale solo los grupos de skills relevantes para su trabajo. Esto ayuda a que su agente active de manera confiable las skills correctas. Para agregar más grupos de skills posteriormente, vuelva a ejecutar el instalador.
5. De forma predeterminada, su agente crea una nueva sesión de MATLAB cuando lo invoca. Para conectar su agente a la sesión de MATLAB existente, ejecute este comando en la ventana de comandos de MATLAB.

```
shareMATLABSession()
```

Si está ejecutando varias sesiones de MATLAB, el agente se conecta a la sesión de MATLAB donde ejecutó este comando más recientemente.

Como alternativa, también puede agregar este comando a su [Startup Script](https://www.mathworks.com/help/matlab/ref/startup.html) de MATLAB.

### Verificar
Pregunte a su agente:

```
¿Qué versión de MATLAB se está ejecutando? Quiero ver una lista de las toolboxes instaladas.
```

### Ejecutar y probar código de MATLAB usando herramientas MCP
Después de instalar MATLAB Agentic Toolkit, su agente puede usar estas herramientas proporcionadas por MATLAB MCP Server.

| Tareas que puede pedir a su agente | Herramienta usada por el agente |
|------|------------------------|
| Ejecutar código de MATLAB y devolver la salida de la ventana de comandos | `evaluate_matlab_code` |
| Ejecutar un programa de MATLAB | `run_matlab_file` |
| Ejecutar pruebas mediante `runtests` con resultados estructurados | `run_matlab_test_file`|
| Análisis de código estático usando Code Analyzer | `check_matlab_code` |
| Ver una lista de la versión de MATLAB y las toolboxes instaladas | `detect_matlab_toolboxes` |

El servidor también proporciona dos recursos MCP: `matlab_coding_guidelines` (estándares de codificación) y `plain_text_live_code_guidelines` (reglas de formato de Live Script). Estos recursos proporcionan información de referencia que los agentes pueden consultar según sea necesario.

### Ejecutar flujos de trabajo de MATLAB usando skills del agente
Después de instalar MATLAB Agentic Toolkit, su agente puede usar skills seleccionadas por MathWorks&reg;. Para obtener mejores resultados, instale solo los grupos de skills relevantes para su trabajo — los agentes activan skills de manera más confiable cuando hay menos cargadas. También puede activar manualmente una skill específica por nombre (por ejemplo, `/matlab-write-tests` en Claude Code) para garantizar que se cargue. Para leer detalles sobre todas las skills, consulte el [catálogo de skills](skills-catalog/README.es.md). Los grupos de skills incluyen:

<!-- BEGIN SKILLS -->
#### Skills de MATLAB

| Grupo de skills | Descripción |
|-------------|-------------|
| [**MATLAB Core**](skills-catalog/README.es.md#matlab-core-matlab-core) | Crear, depurar, probar, revisar y administrar código e instalaciones de MATLAB |
| [**MATLAB App Building**](skills-catalog/README.es.md#matlab-app-building-matlab-app-building) | Compilar aplicaciones de MATLAB programáticamente usando componentes de interfaz de usuario, diseños, callbacks e integración web |
| [**MATLAB Data Import and Analysis**](skills-catalog/README.es.md#matlab-data-import-and-analysis-matlab-data-import-and-analysis) | Importar, exportar y analizar datos en MATLAB usando tablas, horarios, filtrado, agregación y operaciones de series temporales |
| [**MATLAB Environment and Settings**](skills-catalog/README.es.md#matlab-environment-and-settings-matlab-environment-and-settings) | Comparar ajustes de MATLAB entre versiones y migrar scripts de inicio a rutas de ajustes correctas |
| [**MATLAB External Language Interfaces**](skills-catalog/README.es.md#matlab-external-language-interfaces-matlab-external-language-interfaces) | Invocar bibliotecas de Python&reg; desde MATLAB y actualizar archivos MEX a la API interleaved complex |
| [**MATLAB Programming**](skills-catalog/README.es.md#matlab-programming-matlab-programming) | Escribir funciones de MATLAB robustas con entradas validadas |
| [**MATLAB Software Development**](skills-catalog/README.es.md#matlab-software-development-matlab-software-development) | Modernizar código heredado, optimizar rendimiento y memoria, documentar y crear toolboxes, crear proyectos y desarrollar planes de compilación |

#### Skills de toolboxes

| Grupo de skills | Productos compatibles |
|-------------|--------------------|
| [**Aerospace**](skills-catalog/README.es.md#aerospace-aerospace) | MATLAB, Aerospace Toolbox&trade; |
| [**AI and Statistics**](skills-catalog/README.es.md#ai-and-statistics-ai-and-statistics) | MATLAB, Simulink, Curve Fitting Toolbox&trade;, Deep Learning Toolbox&trade;, Embedded Coder&trade;, Fixed-Point Designer&trade;, MATLAB Coder&trade;, MATLAB Compiler SDK&trade;, MATLAB Report Generator&trade;, Optimization Toolbox&trade;, Parallel Computing Toolbox&trade;, Statistics and Machine Learning Toolbox&trade;, Deep Learning Toolbox Converter for ONNX Model Format&trade;, Deep Learning Toolbox Converter for PyTorch Models&trade; y Deep Learning Toolbox Converter for TensorFlow Models&trade; |
| [**Automotive**](skills-catalog/README.es.md#automotive-automotive) | MATLAB, Simulink, Automated Driving Toolbox&trade;, Computer Vision Toolbox&trade;, RoadRunner, RoadRunner Scenario, RoadRunner Scene Builder, Sensor Fusion and Tracking Toolbox&trade;, Automated Driving Toolbox Interface for Eclipse SUMO Traffic Simulator&trade; y Scenario Builder for Automated Driving Toolbox&trade; |
| [**Cloud Solutions**](skills-catalog/README.es.md#cloud-solutions-cloud-solutions) | MATLAB, MATLAB Drive&trade; |
| [**Code Generation**](skills-catalog/README.es.md#code-generation-code-generation) | MATLAB, Embedded Coder, Fixed-Point Designer, GPU Coder&trade;, MATLAB Coder, MATLAB Test&trade;, Parallel Computing Toolbox y MATLAB Coder Support Package for PyTorch and LiteRT Models&trade; |
| [**Computational Biology**](skills-catalog/README.es.md#computational-biology-computational-biology) | MATLAB, SimBiology&trade; y Statistics and Machine Learning Toolbox |
| [**Computational Finance**](skills-catalog/README.es.md#computational-finance-computational-finance) | MATLAB, Datafeed Toolbox&trade;, Financial Instruments Toolbox&trade;, Financial Toolbox&trade; y Spreadsheet Link&trade; |
| [**Control Systems**](skills-catalog/README.es.md#control-systems-control-systems) | MATLAB, Control System Toolbox&trade;, Predictive Maintenance Toolbox&trade;, Signal Processing Toolbox&trade;, Statistics and Machine Learning Toolbox y System Identification Toolbox&trade; |
| [**Image Processing and Computer Vision**](skills-catalog/README.es.md#image-processing-and-computer-vision-image-processing-and-computer-vision) | MATLAB, Computer Vision Toolbox, Deep Learning Toolbox, Image Processing Toolbox&trade;, Lidar Toolbox&trade;, Medical Imaging Toolbox&trade; y Optical Design and Simulation Library for Image Processing Toolbox&trade; |
| [**Math and Optimization**](skills-catalog/README.es.md#math-and-optimization-math-and-optimization) | MATLAB, Optimization Toolbox, Partial Differential Equation Toolbox&trade; y Symbolic Math Toolbox&trade; |
| [**Parallel Computing**](skills-catalog/README.es.md#parallel-computing-parallel-computing) | MATLAB, Parallel Computing Toolbox y MATLAB Parallel Server&trade; |
| [**Radar**](skills-catalog/README.es.md#radar-radar) | MATLAB, Mapping Toolbox&trade;, Phased Array System Toolbox&trade;, Radar Toolbox&trade;, Sensor Fusion and Tracking Toolbox y Signal Processing Toolbox |
| [**Reporting and Database Access**](skills-catalog/README.es.md#reporting-and-database-access-reporting-and-database-access) | MATLAB, Database Toolbox&trade;, MATLAB Report Generator, Parallel Computing Toolbox y Simulink Report Generator&trade; |
| [**RF and Mixed Signal**](skills-catalog/README.es.md#rf-and-mixed-signal-rf-and-mixed-signal) | MATLAB, Simulink, Antenna Toolbox&trade;, Mixed-Signal Blockset&trade;, RF Blockset&trade;, RF PCB Toolbox&trade;, RF Toolbox&trade;, SerDes Toolbox&trade;, Signal Integrity Toolbox, Signal Processing Toolbox y Statistics and Machine Learning Toolbox |
| [**Robotics and Autonomous Systems**](skills-catalog/README.es.md#robotics-and-autonomous-systems-robotics-and-autonomous-systems) | MATLAB, Navigation Toolbox&trade;, UAV Toolbox&trade; y Robotics System Toolbox&trade; |
| [**Signal Processing**](skills-catalog/README.es.md#signal-processing-signal-processing) | MATLAB, Simulink, Audio Toolbox&trade;, DSP HDL Toolbox&trade;, DSP System Toolbox&trade;, Fixed-Point Designer, HDL Coder&trade;, Signal Processing Toolbox y Wavelet Toolbox&trade; |
| [**Test and Measurement**](skills-catalog/README.es.md#test-and-measurement-test-and-measurement) | MATLAB, Data Acquisition Toolbox&trade;, Image Acquisition Toolbox&trade;, Image Processing Toolbox, Industrial Communication Toolbox&trade;, Vehicle Network Toolbox&trade; y MATLAB Support Package for Arduino Hardware&trade; |
| [**Wireless Communications**](skills-catalog/README.es.md#wireless-communications-wireless-communications) | MATLAB, 5G Toolbox&trade;, Bluetooth&reg; Toolbox&trade;, Communications Toolbox&trade;, Satellite Communications Toolbox&trade;, Wireless Network Toolbox&trade;, Wireless Testbench&trade;, WLAN Toolbox&trade; y Wireless Testbench Support Package for NI USRP Radios&trade; |
<!-- END SKILLS -->
---
## Actualizar MATLAB Agentic Toolkit

Para actualizar el toolkit, descargue el complemento del instalador más reciente haciendo clic en [agenticToolkitInstaller.mltbx](https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx). Abra el archivo descargado con MATLAB y ejecute este comando en MATLAB.

```matlab
setupAgenticToolkit("update")
```

Esto actualiza las skills, configuraciones y el binario del servidor MCP para MATLAB y Simulink Agentic Toolkits.

---
## Consideraciones de seguridad
Cuando use MATLAB Agentic Toolkit y MATLAB MCP Server, debe revisar y validar exhaustivamente todas las llamadas a herramientas antes de ejecutarlas. Mantenga siempre un humano en el ciclo para las acciones importantes y proceda solo cuando tenga seguridad de que la llamada hará exactamente lo que espera. Para obtener más información, consulte [User Interaction Model (MCP)](https://modelcontextprotocol.io/specification/latest/server/tools#user-interaction-model) y [Security Considerations (MCP)](https://modelcontextprotocol.io/specification/latest/server/tools#security-considerations).

---
## Recopilación de datos

MATLAB MCP Server recopila datos de uso anonimizados de forma predeterminada. Para obtener más detalles, consulte [Data Collection](https://github.com/matlab/matlab-mcp-server/blob/main/l10n/README.es.md#recopilación-de-datos) en la documentación del servidor MCP. Para desactivar la recopilación, consulte [Disable Data Collection](../Configuration_and_Troubleshooting.md#disable-data-collection).

---
## Licencia y uso
La licencia está disponible en el archivo [LICENSE.md](../LICENSE.md) de este repositorio de GitHub.

Los servidores MCP solo están permitidos para su uso con MATLAB de acuerdo con el MathWorks Software License Agreement, y no deben ser compartidos por múltiples usuarios. Contacte con MathWorks si necesita admitir el uso de servidores compartidos o centralizados.

---
## Soporte y contribuciones
MathWorks le anima a usar este repositorio y proporcionar comentarios. Las solicitudes de cambios (pull requests) no están habilitadas en este repositorio. Para solicitar soporte técnico o enviar una solicitud de mejora, [cree un issue en GitHub](https://github.com/matlab/matlab-agentic-toolkit/issues) o [contacte con el soporte técnico](https://www.mathworks.com/support/contact_us.html).

----

Copyright 2026 The MathWorks, Inc.

----
