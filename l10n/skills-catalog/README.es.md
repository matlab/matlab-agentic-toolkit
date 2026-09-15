<!--
Source English Markdown:
- File: ./skills-catalog/README.md
- Branch: main
- Commit: cd7a55815df574409a09d14d6333641cc86cff3e
-->

# Catálogo de Skills

<p align="center">
  <a href="../../skills-catalog/README.md">English</a> •
  Español •
  <a href="README.ja.md">日本語</a> •
  <a href="README.ko.md">한국어</a> •
  <a href="README.zh-cn.md">简体中文</a>
</p>

El catálogo de skills organiza las skills del agente en grupos. Cada grupo contiene una o más carpetas de skills, cada una con un archivo `SKILL.md` y un archivo `manifest.yaml`. El archivo `manifest.yaml` contiene metadatos sobre el skill.

## Skills

<!-- BEGIN SKILLS -->
### MATLAB Core ([`matlab-core`](../../skills-catalog/matlab-core/))

Crear, depurar, probar, revisar y administrar código e instalaciones de MATLAB&reg;

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-create-live-script` | Crear MATLAB Live Scripts en texto plano con texto enriquecido, ecuaciones LaTeX y figuras en línea. |
| `matlab-debug-code` | Diagnosticar errores de MATLAB y comportamientos inesperados. |
| `matlab-install-products` | Instalar productos de MathWorks&reg; desde la línea de comandos usando MATLAB Package Manager (mpm). |
| `matlab-list-products` | Mostrar todos los productos y paquetes de soporte de MATLAB instalados para una carpeta de instalación de MATLAB dada. |
| `matlab-read-documentation` | Obtener y navegar la documentación de MathWorks específica para su versión de MATLAB para determinar la sintaxis correcta de funciones, flujos de trabajo completos y buenas prácticas para trabajar con MATLAB y Simulink&reg;. |
| `matlab-review-code` | Revisar código de MATLAB en términos de calidad, rendimiento, mantenibilidad y cumplimiento de los estándares de codificación de MathWorks. |
| `matlab-run-tests` | Ejecutar suites de pruebas de MATLAB, recopilar cobertura de código y configurar pipelines CI/CD. |
| `matlab-write-tests` | Generar y estructurar pruebas unitarias de MATLAB usando frameworks de pruebas basados en clases. |

### MATLAB App Building ([`matlab-app-building`](../../skills-catalog/matlab-app-building/))

Compilar aplicaciones de MATLAB programáticamente usando componentes de interfaz de usuario, diseños, callbacks e integración web

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-apply-theme` | Aplicar paletas de colores, temas de marca, modo oscuro y estilos condicionales a gráficas de MATLAB y aplicaciones uifigure. |
| `matlab-build-app` | Compilar aplicaciones de MATLAB con selección guiada de arquitectura (UIFigure o UIHTML), arquetipos de diseño y planes de implementación estructurados. Para aplicaciones UIFigure, opcionalmente serializar a formato App Designer (.mlapp o texto plano). |
| `matlab-build-chart` | Crear y personalizar gráficas de MATLAB con manejo correcto de ejes, diseño moderno, anotaciones, interactividad y patrones de animación. |

### MATLAB Data Import and Analysis ([`matlab-data-import-and-analysis`](../../skills-catalog/matlab-data-import-and-analysis/))

Importar, exportar y analizar datos en MATLAB usando tablas, horarios, filtrado, agregación y operaciones de series temporales

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-analyze-data` | Analizar datos en MATLAB usando tablas, horarios, arreglos numéricos y datos reticulados — filtrado, agregación, suavizado, limpieza y operaciones de series temporales. |
| `matlab-choose-big-data-solution` | Elegir la herramienta de MATLAB adecuada para procesar datos tabulares grandes que podrían no caber en memoria. |
| `matlab-import-export-data` | Importar y exportar datos tabulares, estructurados y binarios con fidelidad entre herramientas. |
| `matlab-secure-credentials` | Almacenar, recuperar y pasar credenciales de forma segura en MATLAB usando el vault integrado de MATLAB. |

### MATLAB Environment and Settings ([`matlab-environment-and-settings`](../../skills-catalog/matlab-environment-and-settings/))

Comparar ajustes de MATLAB entre versiones y migrar scripts de inicio a rutas de ajustes correctas

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-migrate-settings` | Comparar ajustes de MATLAB entre versiones y actualizar archivos de código de MATLAB (.m) que configuran programáticamente los ajustes de MATLAB para usar las rutas de ajustes correctas para la versión de destino. |

### MATLAB External Language Interfaces ([`matlab-external-language-interfaces`](../../skills-catalog/matlab-external-language-interfaces/))

Invocar bibliotecas de Python&reg; desde MATLAB y actualizar archivos MEX a la API interleaved complex

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-call-python` | Invocar bibliotecas de Python desde MATLAB usando la interfaz py. |
| `matlab-upgrade-mex-ic` | Convertir archivos MEX de C, C++ y Fortran de la API separate complex a la API interleaved complex con guards MX_HAS_INTERLEAVED_COMPLEX para compilaciones SC/IC y verificación de rendimiento. |

### MATLAB Programming ([`matlab-programming`](../../skills-catalog/matlab-programming/))

Escribir funciones de MATLAB robustas con entradas validadas

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-validate-function-arguments` | Validar entradas de funciones de MATLAB usando el bloque arguments. |

### MATLAB Software Development ([`matlab-software-development`](../../skills-catalog/matlab-software-development/))

Modernizar código heredado, optimizar rendimiento y memoria, documentar y crear toolboxes, crear proyectos y desarrollar planes de compilación

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-instrument-opentelemetry-tracing` | Agregar spans de trazado OpenTelemetry a funciones de MATLAB con propagación de contexto y ciclo de vida correctos. |
| `matlab-modernize-code` | Modernizar funciones y patrones eliminados o desaconsejados de MATLAB. |
| `matlab-optimize-memory` | Encontrar y corregir cuellos de botella de memoria en código de MATLAB usando un flujo de trabajo estructurado de medición-perfilado-optimización-verificación. |
| `matlab-optimize-performance` | Optimizar el rendimiento del código de MATLAB. |
| `matlab-package-toolbox` | Empaquetar código de MATLAB como una toolbox instalable .mltbx. |
| `matlab-write-help` | Generar o mejorar texto de ayuda de MATLAB siguiendo los estándares de documentación de MathWorks. |
| `matlab-write-performance-tests` | Escribir pruebas de rendimiento de MATLAB usando el framework matlab.perftest.TestCase. |

### Aerospace ([`aerospace`](../../skills-catalog/aerospace/))

Soporte para MATLAB y Aerospace Toolbox&trade;

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-compute-aerospace-environment` | Calcular propiedades del entorno aeroespacial (atmósfera, gravedad, viento, campo magnético, geoide, clima espacial, efemérides, orientación terrestre) usando funciones de Aerospace Toolbox. |
| `matlab-convert-aerospace-coordinates` | Convertir marcos de coordenadas aeroespaciales, rotaciones, tiempo y unidades. |

### AI and Statistics ([`ai-and-statistics`](../../skills-catalog/ai-and-statistics/))

Soporte para MATLAB, Simulink, Curve Fitting Toolbox&trade;, Deep Learning Toolbox&trade;, Embedded Coder&trade;, Fixed-Point Designer&trade;, MATLAB Coder&trade;, MATLAB Compiler SDK&trade;, MATLAB Report Generator&trade;, Optimization Toolbox&trade;, Parallel Computing Toolbox&trade;, Statistics and Machine Learning Toolbox&trade;, Deep Learning Toolbox Converter for ONNX Model Format&trade;, Deep Learning Toolbox Converter for PyTorch Models&trade; y Deep Learning Toolbox Converter for TensorFlow Models&trade;

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-analyze-reliability` | Ajustar distribuciones de vida y modelos de vida acelerada para análisis de fiabilidad. |
| `matlab-classify-tabular-data` | Clasificar datos tabulares comparando modelos candidatos e identificando el nivel superior estadísticamente equivalente. |
| `matlab-create-experiment` | Crear experimentos para la aplicación Experiment Manager analizando código de usuario y generando las funciones e hiperparámetros apropiados. |
| `matlab-deploy-embedded-ai` | Desplegar modelos de IA en hardware integrado usando MATLAB y Simulink. |
| `matlab-engineer-tabular-features` | Diseñar y seleccionar las mejores características para clasificación o regresión tabular de respuesta única en MATLAB. |
| `matlab-fit-curve` | Ajustar curvas y superficies interactivamente usando la aplicación Curve Fitter. |
| `matlab-import-external-ai-model` | Importar modelos de deep learning de PyTorch, ONNX y Keras a MATLAB y verificar la corrección numérica. |
| `matlab-train-network` | Entrenar, evaluar y exportar redes neuronales a Simulink usando las API recomendadas. Migrar código heredado de entrenamiento de redes neuronales a reemplazos modernos. |
| `matlab-use-machine-learning-apps` | Entrenar, comparar y exportar modelos de machine learning usando las aplicaciones Classification Learner y Regression Learner. |

### Automotive ([`automotive`](../../skills-catalog/automotive/))

Soporte para MATLAB, Simulink, Automated Driving Toolbox&trade;, Computer Vision Toolbox&trade;, RoadRunner, RoadRunner Scenario, RoadRunner Scene Builder, Sensor Fusion and Tracking Toolbox&trade;, Automated Driving Toolbox Interface for Eclipse SUMO Traffic Simulator&trade; y Scenario Builder for Automated Driving Toolbox&trade;

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-cosimulate-sumo-simulink` | Compilar modelos de Simulink que co-simulan con el simulador de tráfico Eclipse&trade; SUMO. |
| `matlab-import-driving-data` | Importar datos de sensores de conducción grabados (GPS, cámara, lidar, tracks de actores) en objetos scenariobuilder.* y sincronizar, recortar, desplazar y normalizar marcas de tiempo antes de la construcción del escenario. |
| `matlab-use-ncap-protocol` | Generar escenarios de prueba Euro NCAP y variantes, traducir entre simuladores y calcular puntuaciones. |
| `matlab-use-scenario-builder` | Compilar escenas de conducción, escenarios, superficies de carretera y activos 3D a partir de datos de sensores grabados y exportar a RoadRunner, drivingScenario, OpenSCENARIO, OpenDRIVE, OpenCRG o Unreal Engine&reg;. |
| `roadrunner-asset-mapping` | Generar tablas de búsqueda de rutas de activos de RoadRunner para conversiones de formato de mapa en MATLAB. |
| `roadrunner-build-scenario-from-osc` | Interpretar un archivo OpenSCENARIO 1.x y recrear el escenario programáticamente en RoadRunner. |
| `roadrunner-convert-lanelet2-to-rrhd` | Convertir mapas Lanelet2 (.osm) a formato RoadRunner HD Map (.rrhd) usando MATLAB. |
| `roadrunner-core` | Conectarse a RoadRunner desde MATLAB y administrar el ciclo de vida de proyectos, escenas y escenarios. |
| `roadrunner-import-scene` | Conectarse a RoadRunner e importar archivos HD Map u OpenDRIVE en una nueva escena usando MATLAB. |
| `roadrunner-rrhd-authoring` | Compilar entidades de RoadRunner HD Map en MATLAB — carriles, límites, marcas, intersecciones, señales, semáforos, barreras, estacionamiento. |
| `roadrunner-scenario-authoring` | Crear escenarios de conducción de RoadRunner programáticamente desde MATLAB. |
| `roadrunner-scenario-simulating` | Simular escenarios de RoadRunner programáticamente mediante co-simulación con MATLAB y Simulink. |

### Cloud Solutions ([`cloud-solutions`](../../skills-catalog/cloud-solutions/))

Soporte para MATLAB, MATLAB Drive&trade;

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-share-content` | Compartir contenido de MATLAB cargándolo a GitHub&reg;, MATLAB Drive o File Exchange y generando URLs "Open in MATLAB Online&trade;". |

### Code Generation ([`code-generation`](../../skills-catalog/code-generation/))

Soporte para MATLAB, Embedded Coder, Fixed-Point Designer, GPU Coder&trade;, MATLAB Coder, MATLAB Test&trade;, Parallel Computing Toolbox y MATLAB Coder Support Package for PyTorch and LiteRT Models&trade;

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-deploy-ai-model` | Generar código C/C++ o CUDA a partir de modelos PyTorch ExportedProgram (.pt2) o LiteRT (.tflite) usando loadPyTorchExportedProgram, loadLiteRTModel y codegen. Incluye flujos de trabajo de integración con Simulink. |
| `matlab-deploy-embedded-code` | Desplegar código generado por MATLAB en hardware integrado con verificación PIL. |
| `matlab-generate-code` | Generar, verificar y acelerar código C/C++ o CUDA a partir de MATLAB usando MATLAB Coder, Embedded Coder o GPU Coder. |
| `matlab-optimize-gpu-codegen` | Optimizar funciones de MATLAB para GPU Coder para generar código CUDA más rápido. |
| `matlab-review-fi-object-code` | Revisar código de MATLAB de punto fijo (fi) en términos de rendimiento, eficiencia de generación de código y corrección. |

### Computational Biology ([`computational-biology`](../../skills-catalog/computational-biology/))

Soporte para MATLAB, SimBiology&trade; y Statistics and Machine Learning Toolbox

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `simbiology-build-model` | Compilar modelos de SimBiology desde cero, modificar modelos existentes y generar diseños de diagramas. |
| `simbiology-fit-model` | Ajustar parámetros de modelos de SimBiology a datos. |
| `simbiology-simulate-model` | Ejecutar simulaciones, explorar parámetros, explorar escenarios hipotéticos y realizar análisis de sensibilidad en modelos de SimBiology. |

### Computational Finance ([`computational-finance`](../../skills-catalog/computational-finance/))

Soporte para MATLAB, Datafeed Toolbox&trade;, Financial Instruments Toolbox&trade;, Financial Toolbox&trade; y Spreadsheet Link&trade;

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-access-datafeed` | Conectarse a Bloomberg&reg;, FRED&reg;, Haver Analytics&reg; y LSEG&reg; Datastream para recopilar datos financieros y económicos usando Datafeed Toolbox. |
| `matlab-optimize-portfolio` | Formular y resolver problemas de optimización de cartera de media-varianza. |
| `matlab-price-instrument` | Valorar instrumentos financieros usando Monte Carlo, FFT o árboles de tasa de interés. |
| `matlab-use-spreadsheet-link` | Escribir macros VBA y funciones de hoja de cálculo para intercambiar datos con Excel usando Spreadsheet Link. |

### Control Systems ([`control-systems`](../../skills-catalog/control-systems/))

Soporte para MATLAB, Control System Toolbox&trade;, Predictive Maintenance Toolbox&trade;, Signal Processing Toolbox&trade;, Statistics and Machine Learning Toolbox y System Identification Toolbox&trade;

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-extract-battery-features` | Extraer características de baterías a partir de datos de pruebas de ciclado para análisis de degradación y salud. |
| `matlab-extract-rotating-machinery-features` | Extraer características de datos de vibración de maquinaria rotativa para monitoreo de condición y detección de fallas. |
| `matlab-identify-linear-system` | Identificar modelos dinámicos lineales a partir de datos de medición usando System Identification Toolbox. |

### Image Processing and Computer Vision ([`image-processing-and-computer-vision`](../../skills-catalog/image-processing-and-computer-vision/))

Soporte para MATLAB, Computer Vision Toolbox, Deep Learning Toolbox, Image Processing Toolbox&trade;, Lidar Toolbox&trade;, Medical Imaging Toolbox&trade; y Optical Design and Simulation Library for Image Processing Toolbox&trade;

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-analyze-spectral-images` | Leer, procesar, analizar, etiquetar y clasificar imágenes hiperespectrales y multiespectrales. |
| `matlab-display-image` | Mostrar imágenes y anotaciones para procesamiento de imágenes, visión artificial e inspección visual. |
| `matlab-display-volume` | Mostrar volúmenes de imágenes 3D, volúmenes de imágenes médicas, mallas de superficie y anotaciones para procesamiento de imágenes 3D. |
| `matlab-integrate-pytorch-vision` | Crear interfaces de MATLAB para modelos de procesamiento de imágenes y visión artificial de Python a partir de repositorios de GitHub o paquetes pip usando MPyReq. |
| `matlab-model-optics` | Compilar, importar, analizar, optimizar y toleranciar sistemas ópticos y recubrimientos usando la Optical Design and Simulation Library. |
| `matlab-process-large-images` | Procesar imágenes grandes usando blockedImage. |
| `matlab-read-medical-data` | Leer, escribir y manipular datos de imágenes médicas (DICOM, NIfTI, NRRD) usando las API de Image Processing Toolbox y Medical Imaging Toolbox. |
| `matlab-read-write-point-cloud-file` | Leer y escribir datos de nubes de puntos 3D en formatos PLY, PCD, LAS/LAZ, PCAP, E57 e IDC. |
| `matlab-recognize-text` | Compilar pipelines de OCR en MATLAB usando la función ocr(). |
| `matlab-register-point-clouds` | Registrar y alinear nubes de puntos 3D usando algoritmos ICP, NDT, LOAM, FGR, correlación de fase y CPD. |

### Math and Optimization ([`math-and-optimization`](../../skills-catalog/math-and-optimization/))

Soporte para MATLAB, Optimization Toolbox, Partial Differential Equation Toolbox&trade; y Symbolic Math Toolbox&trade;

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-solve-optimization` | Formular, resolver y validar problemas de optimización de MATLAB usando enfoques basados en problemas y basados en solvers. |
| `matlab-solve-pde` | Compilar y resolver modelos de elementos finitos para problemas térmicos, estructurales y electromagnéticos usando PDE Toolbox&trade;. |
| `matlab-use-symbolic-math` | Generar código de MATLAB correcto usando Symbolic Math Toolbox para soluciones analíticas, resolución de ecuaciones, cálculo, transformadas y generación de código. |

### Parallel Computing ([`parallel-computing`](../../skills-catalog/parallel-computing/))

Soporte para MATLAB, Parallel Computing Toolbox y MATLAB Parallel Server&trade;

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-diagnose-parfor` | Diagnosticar y corregir errores de clasificación de variables parfor en MATLAB. |
| `matlab-discover-clusters` | Descubrir clusters de computación paralela y administrar perfiles de cluster. |
| `matlab-set-up-worker-state` | Configurar el entorno de workers y el estado por worker para pools paralelos. |
| `matlab-setup-gpu` | Detectar y validar la disponibilidad de GPU para computación GPU en MATLAB. |
| `matlab-use-thread-pool` | Acelerar la computación paralela local usando pool paralelo basado en hilos. |

### Radar ([`radar`](../../skills-catalog/radar/))

Soporte para MATLAB, Mapping Toolbox&trade;, Phased Array System Toolbox&trade;, Radar Toolbox&trade;, Sensor Fusion and Tracking Toolbox y Signal Processing Toolbox

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-design-radar-waveform` | Diseñar, seleccionar y analizar formas de onda de radar y sonar usando Phased Array System Toolbox. |
| `matlab-design-radar` | Diseñar, configurar y analizar sistemas de radar en la aplicación Radar Designer. |
| `matlab-import-tracking-data` | Importar datos de seguimiento sin procesar (CSV, XLSX, TXT o tablas MATLAB) en arreglos objectDetection y arreglos objectTrack usados por Sensor Fusion and Tracking Toolbox. |
| `matlab-simulate-radar-detections` | Simular detecciones estadísticas de radar para escenarios de radar de vigilancia y seguimiento. |

### Reporting and Database Access ([`reporting-and-database-access`](../../skills-catalog/reporting-and-database-access/))

Soporte para MATLAB, Database Toolbox&trade;, MATLAB Report Generator, Parallel Computing Toolbox y Simulink Report Generator&trade;

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-connect-databricks` | Conectar MATLAB a Databricks&reg; a través de Spark o JDBC para lectura y escritura de datos. |
| `matlab-generate-report` | Generar informes estructurados en PDF, Word y HTML a partir de datos de MATLAB y modelos de Simulink usando la API de Report Generator. |
| `matlab-use-database` | Leer, escribir, actualizar y administrar bases de datos relacionales desde MATLAB. |
| `matlab-use-duckdb` | Usar DuckDB desde MATLAB como motor de operaciones no matemáticas en archivos tabulares grandes y como base de datos integrada sin configuración. Incluye enrutamiento de pre-vuelo, límites de operaciones y un flujo de trabajo de perfil-operación-cierre. |

### RF and Mixed Signal ([`rf-and-mixed-signal`](../../skills-catalog/rf-and-mixed-signal/))

Soporte para MATLAB, Simulink, Antenna Toolbox&trade;, Mixed-Signal Blockset&trade;, RF Blockset&trade;, RF PCB Toolbox&trade;, RF Toolbox&trade;, SerDes Toolbox&trade;, Signal Integrity Toolbox, Signal Processing Toolbox y Statistics and Machine Learning Toolbox

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-analyze-ams-waveform` | Medir ruido de fase, jitter y temporización de formas de onda de simulación AMS usando Mixed-Signal Blockset. |
| `matlab-analyze-antenna-structures` | Diseñar y analizar estructuras de antena eléctricamente grandes — reflectores, reflectarrays, antenas instaladas en plataformas y sección transversal de radar. |
| `matlab-analyze-em` | Calcular parámetros S, pérdida de inserción, campos y corrientes para validación de rendimiento de PCB de RF. |
| `matlab-analyze-pcb-pdn` | Analizar distribución de voltaje y corriente DC de PDN, caída IR y verificación de reglas de diseño en layouts de PCB. |
| `matlab-assemble-pcb-layout` | Compilar estructuras de PCB personalizadas con pcbComponent, formas, operaciones booleanas, alimentaciones y apilamientos multicapa. |
| `matlab-design-antenna` | Diseñar antenas, arrays y antenas PCB usando MATLAB Antenna Toolbox. Cubre diseño de antenas de catálogo, construcción de antenas personalizadas, diseño de antenas PCB, arrays finitos e infinitos, exploración de diseño acelerada por IA y optimización. |
| `matlab-design-pcb-coupler` | Diseñar acopladores Wilkinson, branchline, ratrace y direccionales, divisores corporativos y lentes Rotman. |
| `matlab-design-pcb-filter` | Diseñar filtros RF paso banda, paso bajo y eliminador de banda usando topologías hairpin, líneas acopladas, combline, stub y SIW. |
| `matlab-design-pcb-passive` | Diseñar inductores espirales, capacitores interdigitales, baluns, resonadores y desfasadores para circuitos RF. |
| `matlab-design-pcb-transmission-line` | Diseñar líneas de transmisión microstrip, stripline, CPW y par diferencial con control de impedancia y análisis de diafonía. |
| `matlab-export-session-script` | Exportar código de MATLAB de la conversación a un script .m limpio y ejecutable. |
| `matlab-integrate-antenna` | Integrar antenas en sistemas RF usando MATLAB Antenna Toolbox y RF Toolbox. Cubre diseño de red de adaptación de impedancia, creación de antena medida, propagación RF y planificación de sitio, y estimación de SAR. |
| `matlab-integrate-pcb-circuit` | Conectar en cascada componentes PCB, agregar elementos concentrados y exportar archivos Touchstone para circuitos RF multicomponente. |
| `matlab-manage-pcb-material` | Definir sustratos dieléctricos, conductores metálicos, apilamientos multicapa y modelos de pérdida para simulación de PCB de RF. |
| `matlab-model-ams-systems` | Modelar sintetizadores de frecuencia PLL a partir de hojas de datos de IC o especificaciones de sistema usando Mixed-Signal Blockset. Extraer parámetros, seleccionar arquitectura, ensamblar modelos de Simulink, diseñar filtros de lazo, validar ruido de fase. |
| `matlab-model-rf` | Diseñar, analizar y simular sistemas RF en MATLAB usando RF Toolbox y RF Blockset -- desde E/S de parámetros S hasta simulación completa en el dominio del tiempo con Circuit Envelope. |
| `matlab-model-serdes-systems` | Modelar, simular y optimizar sistemas Serializer/Deserializer (SerDes) — enlaces serie y paralelo — usando MATLAB SerDes Toolbox. |
| `matlab-model-via` | Modelar vías con pads, antipads y vías de retorno a tierra para transiciones de capa de PCB de alta velocidad. |
| `matlab-optimize-pcb-design` | Optimizar dimensiones de componentes de PCB de RF para ancho de banda, pérdida de retorno o área usando patternsearch y surrogateopt. |
| `matlab-read-pcb-layout` | Importar archivos Gerber, ODB++ y Allegro .brd e inspeccionar redes, capas, formas y apilamientos. |
| `matlab-write-pcb-layout` | Exportar diseños pcbComponent a archivos Gerber para fabricación de PCB. |

### Robotics and Autonomous Systems ([`robotics-and-autonomous-systems`](../../skills-catalog/robotics-and-autonomous-systems/))

Soporte para MATLAB, Navigation Toolbox&trade;, UAV Toolbox&trade; y Robotics System Toolbox&trade;

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-compute-gnss-position` | Calcular posiciones de sistema de posicionamiento global (GPS) o sistema global de navegación por satélite (GNSS) multi-constelación a partir de datos RINEX v3 usando rinexread, gnssmeasurements, receiverposition y gnssoptions. |
| `matlab-connect-mavlink` | Establecer conexiones MAVLink entre MATLAB y controladores de vuelo PX4 o ArduPilot. |
| `matlab-create-uav-scenario` | Crear y simular escenarios UAV con terreno, edificios, plataformas equipadas con sensores y visualización 3D. |
| `matlab-fuse-inertial-sensors` | Analizar configuraciones de sensores y crear filtros de fusión inercial en MATLAB Navigation Toolbox. |
| `matlab-model-robot-kinematics` | Compilar modelos de manipuladores y validar soluciones cinemáticas en MATLAB. |
| `matlab-plan-robot-motion` | Planificar movimiento libre de colisiones de manipuladores y generar trayectorias parametrizadas en el tiempo. |

### Signal Processing ([`signal-processing`](../../skills-catalog/signal-processing/))

Soporte para MATLAB, Simulink, Audio Toolbox&trade;, DSP HDL Toolbox&trade;, DSP System Toolbox&trade;, Fixed-Point Designer, HDL Coder&trade;, Signal Processing Toolbox y Wavelet Toolbox&trade;

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-analyze-spectrum` | Analizar espectros de señales usando estimadores no paramétricos y paramétricos. |
| `matlab-analyze-time-frequency-content` | Analizar contenido tiempo-frecuencia usando CWT, STFT, synchrosqueezing y coherencia de wavelets. |
| `matlab-configure-scope-object` | Configurar propiedades de bloques de Simulink o objetos de MATLAB relacionados con osciloscopios. |
| `matlab-design-adaptive-filter` | Diseñar e implementar filtros adaptativos usando System objects. |
| `matlab-design-digital-filter` | Diseñar y validar filtros digitales en MATLAB. |
| `matlab-design-dsphdl-ddc` | Diseñar Digital Down Converters optimizados para HDL usando System objects dsphdl. |
| `matlab-extract-signal-features` | Extraer características temporales, frecuenciales y tiempo-frecuencia por trama de señales 1D. |
| `matlab-play-record-audio` | Reproducir y grabar audio en MATLAB usando audiostreamer. |
| `matlab-prepare-signal-data` | Acondicionar señales sin procesar (llenar vacíos, eliminar tendencia, eliminar outliers, eliminar ruido, remuestrear/alinear) y compilar pipelines de signalDatastore para entrenamiento ML -- etiquetas, divisiones estratificadas, enmarcado, lecturas paralelas y transferencia a trainnet. |
| `matlab-process-streaming-audio` | Diseñar y ejecutar cadenas de procesamiento de audio en tiempo real usando objetos de streaming de Audio Toolbox. |
| `matlab-write-audio-plugin` | Crear plugins de Audio Toolbox que compilan a VST/AU mediante validateAudioPlugin y generateAudioPlugin. |

### Test and Measurement ([`test-and-measurement`](../../skills-catalog/test-and-measurement/))

Soporte para MATLAB, Data Acquisition Toolbox&trade;, Image Acquisition Toolbox&trade;, Image Processing Toolbox, Industrial Communication Toolbox&trade;, Vehicle Network Toolbox&trade; y MATLAB Support Package for Arduino Hardware&trade;

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-build-industrial-hmi` | Compilar dashboards SCADA/HMI de grado industrial en MATLAB siguiendo las convenciones ISA-101. Produce una aplicación real de App Designer (.mlapp) delegando la serialización a matlab-build-app cuando está disponible, y recurre a una aplicación programática .m en caso contrario. |
| `matlab-call-nidaqmx` | Traducir funciones C de NI-DAQmx a llamadas calldaqlib correctas en MATLAB. |
| `matlab-connect-arduino` | Descubrir, configurar y conectarse a placas Arduino&reg; desde MATLAB mediante USB. |
| `matlab-connect-bluetooth-low-energy-device` | Descubrir y conectarse a dispositivos periféricos Bluetooth Low Energy desde MATLAB. |
| `matlab-create-custom-arduino-library` | Crear bibliotecas de complementos personalizadas de Arduino para acceder a sensores y periféricos no compatibles desde MATLAB. |
| `matlab-discover-hardware` | Descubrir, inspeccionar y configurar dispositivos de hardware compatibles con MATLAB mediante funciones auxiliares. |
| `matlab-enhance-camera-image` | Diagnosticar y mejorar la calidad de imagen de cámaras conectadas mediante Image Acquisition Toolbox. |
| `matlab-find-pi-assets` | Encontrar y consultar tags de PI Data Archive y elementos de Asset Framework usando piclient y afclient. |
| `matlab-import-export-vehicle-data` | Importar, decodificar y exportar datos de redes vehiculares desde/hacia archivos de registro (ASC, BLF, MDF, DAT, TXT) con manejo correcto de tipos de retorno polimórficos, pipelines de decodificación CAN/CAN FD/LIN y flujos de trabajo de escritura MDF/BLF. |
| `matlab-modernize-daq` | Migrar código heredado de Data Acquisition Toolbox basado en sesiones a la interfaz moderna DataAcquisition. |
| `matlab-use-cameras` | Conectarse y capturar imágenes de cámaras usando la interfaz videoinput de Image Acquisition Toolbox. |
| `matlab-use-opcua-client` | Descubrir servidores OPC UA, crear conexiones seguras de cliente MATLAB y explorar y navegar los nodos del servidor. |
| `matlab-use-vehicle-network` | Configurar, solucionar problemas y analizar comunicación de redes vehiculares CAN/CAN FD en MATLAB usando Vehicle Network Toolbox en todos los proveedores de hardware soportados. |

### Wireless Communications ([`wireless-communications`](../../skills-catalog/wireless-communications/))

Soporte para MATLAB, 5G Toolbox&trade;, Bluetooth&reg; Toolbox&trade;, Communications Toolbox&trade;, Satellite Communications Toolbox&trade;, Wireless Network Toolbox&trade;, Wireless Testbench&trade;, WLAN Toolbox&trade; y Wireless Testbench Support Package for NI USRP Radios&trade;

| Skill | Qué le enseña a su agente |
|-------|---------------------------|
| `matlab-add-awgn` | Agregar ruido blanco gaussiano aditivo (AWGN) y convertir entre SNR, Eb/No, Es/No y SNR por subportadora para simulaciones de comunicaciones. |
| `matlab-design-ofdm-system` | Diseñar y simular sistemas OFDM personalizados usando ofdmmod/ofdmdemod, con configuración de canal con desvanecimiento, ecualización, sincronización (temporización/CFO), codificación LDPC, manejo de SNR, asignación de subportadoras y estimación de canal basada en pilotos. |
| `matlab-generate-5g-waveform` | Generar formas de onda en banda base 5G NR de enlace descendente y ascendente compatibles con 3GPP. |
| `matlab-generate-ble-waveform` | Generar y analizar formas de onda PHY de Bluetooth Low Energy. |
| `matlab-generate-gnss-waveform` | Generar formas de onda GNSS en banda base (GPS, Galileo, NavIC) con deterioros de canal físicamente realistas o especificados por el usuario usando Satellite Communications Toolbox. |
| `matlab-generate-wlan-waveform` | Generar formas de onda WLAN compatibles con el estándar IEEE 802.11. |
| `matlab-set-up-usrp-radio` | Configurar y verificar radios NI USRP para uso con Wireless Testbench. |
| `matlab-simulate-bluetooth-network` | Simular redes Bluetooth a nivel de sistema incluyendo BLE, Classic BR/EDR y LE Audio. |
| `matlab-simulate-wireless-network` | Configurar y ejecutar simulaciones de redes inalámbricas usando wirelessNetworkSimulator. |
| `matlab-transmit-capture-usrp` | Transmitir y capturar formas de onda RF usando Wireless Testbench con radios NI USRP. |

<!-- END SKILLS -->

## Cómo se instalan las skills

Para obtener detalles sobre cómo se instalan estas skills, consulte
[Instalar MATLAB Agentic Toolkit](../README.es.md#instalar-matlab-agentic-toolkit)

----

Copyright 2026 The MathWorks, Inc.

----
