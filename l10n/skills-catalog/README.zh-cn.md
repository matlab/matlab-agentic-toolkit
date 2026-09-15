<!--
Source English Markdown:
- File: ./skills-catalog/README.md
- Branch: main
- Commit: cd7a55815df574409a09d14d6333641cc86cff3e
-->

# 技能目录

<p align="center">
  <a href="../../skills-catalog/README.md">English</a> •
  <a href="README.es.md">Español</a> •
  <a href="README.ja.md">日本語</a> •
  <a href="README.ko.md">한국어</a> •
  简体中文
</p>

技能目录将智能体技能按组进行整理。每个组包含一个或多个技能文件夹，每个文件夹包含一个 `SKILL.md` 文件和一个 `manifest.yaml` 文件。`manifest.yaml` 文件包含有关技能的元数据。

## 技能

<!-- BEGIN SKILLS -->
### MATLAB 核心 ([`matlab-core`](../../skills-catalog/matlab-core/))

创建、调试、测试、审查和管理 MATLAB&reg; 代码及安装

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-create-live-script` | 创建包含富文本、LaTeX 方程式和内联图形的纯文本 MATLAB 实时脚本。 |
| `matlab-debug-code` | 诊断 MATLAB 错误和意外行为。 |
| `matlab-install-products` | 使用 MATLAB Package Manager (mpm) 从命令行安装 MathWorks&reg; 产品。 |
| `matlab-list-products` | 显示给定 MATLAB 安装文件夹中所有已安装的 MATLAB 产品和支持包。 |
| `matlab-read-documentation` | 获取并浏览特定于您的 MATLAB 版本的 MathWorks 文档，以确定正确的函数语法、完整的工作流以及在 MATLAB 和 Simulink&reg; 软件中工作的最佳实践。 |
| `matlab-review-code` | 审查 MATLAB 代码的质量、性能、可维护性以及对 MathWorks 编码标准的遵守情况。 |
| `matlab-run-tests` | 运行 MATLAB 测试套件、收集代码覆盖率并配置 CI/CD 管道。 |
| `matlab-write-tests` | 使用基于类的测试框架生成和组织 MATLAB 单元测试。 |

### MATLAB App 构建 ([`matlab-app-building`](../../skills-catalog/matlab-app-building/))

使用 UI 组件、布局、回调和 Web 集成以编程方式构建 MATLAB App

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-apply-theme` | 将颜色调色板、品牌主题、深色模式和条件样式应用于 MATLAB 图表和 uifigure App。 |
| `matlab-build-app` | 通过引导式架构选择（UIFigure 或 UIHTML）、布局原型和结构化实施计划构建 MATLAB App。对于 UIFigure App，可选择序列化为 App 设计工具格式（.mlapp 或纯文本）。 |
| `matlab-build-chart` | 使用正确的 axes 处理、现代布局、注释、交互性和动画模式创建和自定义 MATLAB 图表。 |

### MATLAB 数据导入和分析 ([`matlab-data-import-and-analysis`](../../skills-catalog/matlab-data-import-and-analysis/))

使用表、timetable、筛选、聚合和时间序列操作在 MATLAB 中导入、导出和分析数据

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-analyze-data` | 使用表、timetable、数值数组和网格数据在 MATLAB 中分析数据 — 筛选、聚合、平滑、清洗和时间序列操作。 |
| `matlab-choose-big-data-solution` | 选择正确的 MATLAB 工具来处理可能无法放入内存的大型表格数据。 |
| `matlab-import-export-data` | 以跨工具保真度导入和导出表格、结构化和二进制数据。 |
| `matlab-secure-credentials` | 使用 MATLAB 内置保管库在 MATLAB 中安全地存储、检索和传递凭据。 |

### MATLAB 环境和设置 ([`matlab-environment-and-settings`](../../skills-catalog/matlab-environment-and-settings/))

比较不同版本之间的 MATLAB 设置差异，并将启动脚本迁移到正确的设置路径

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-migrate-settings` | 比较不同版本之间的 MATLAB 设置，并更新以编程方式配置 MATLAB 设置的 MATLAB 代码文件 (.m)，以使用目标版本的正确设置路径。 |

### MATLAB 外部语言接口 ([`matlab-external-language-interfaces`](../../skills-catalog/matlab-external-language-interfaces/))

从 MATLAB 调用 Python&reg; 库并将 MEX 文件升级到交错式复数 API

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-call-python` | 使用 py. 接口从 MATLAB 调用 Python 库。 |
| `matlab-upgrade-mex-ic` | 将 C、C++ 和 Fortran MEX 文件从独立复数 API 转换为交错式复数 API，并添加用于 SC/IC 构建和性能验证的 MX_HAS_INTERLEAVED_COMPLEX 保护。 |

### MATLAB 编程 ([`matlab-programming`](../../skills-catalog/matlab-programming/))

编写具有经过验证的输入的稳健 MATLAB 函数

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-validate-function-arguments` | 使用 arguments 块验证 MATLAB 函数输入。 |

### MATLAB 软件开发 ([`matlab-software-development`](../../skills-catalog/matlab-software-development/))

现代化遗留代码、优化性能和内存、编写文档和创建工具箱、创建工程和制定构建计划

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-instrument-opentelemetry-tracing` | 使用正确的上下文传播和生命周期向 MATLAB 函数添加 OpenTelemetry 追踪 span。 |
| `matlab-modernize-code` | 现代化已移除或不建议使用的 MATLAB 函数和模式。 |
| `matlab-optimize-memory` | 使用结构化的测量-分析-优化-验证工作流查找并修复 MATLAB 代码中的内存瓶颈。 |
| `matlab-optimize-performance` | 优化 MATLAB 代码的性能。 |
| `matlab-package-toolbox` | 将 MATLAB 代码打包为可安装的 .mltbx 工具箱。 |
| `matlab-write-help` | 按照 MathWorks 文档标准生成或改进 MATLAB 帮助文本。 |
| `matlab-write-performance-tests` | 使用 matlab.perftest.TestCase 框架编写 MATLAB 性能测试。 |

### 航空航天 ([`aerospace`](../../skills-catalog/aerospace/))

支持 MATLAB 和 Aerospace Toolbox&trade;

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-compute-aerospace-environment` | 使用 Aerospace Toolbox 函数计算航空航天环境属性（大气、重力、风、磁场、大地水准面、空间天气、星历、地球方位）。 |
| `matlab-convert-aerospace-coordinates` | 转换航空航天坐标系、旋转、时间和单位。 |

### AI 和统计 ([`ai-and-statistics`](../../skills-catalog/ai-and-statistics/))

支持 MATLAB、Simulink、Curve Fitting Toolbox&trade;、Deep Learning Toolbox&trade;、Embedded Coder&trade;、Fixed-Point Designer&trade;、MATLAB Coder&trade;、MATLAB Compiler SDK&trade;、MATLAB Report Generator&trade;、Optimization Toolbox&trade;、Parallel Computing Toolbox&trade;、Statistics and Machine Learning Toolbox&trade;、Deep Learning Toolbox Converter for ONNX Model Format&trade;、Deep Learning Toolbox Converter for PyTorch Models&trade; 和 Deep Learning Toolbox Converter for TensorFlow Models&trade;

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-analyze-reliability` | 拟合寿命分布和加速寿命模型以进行可靠性分析。 |
| `matlab-classify-tabular-data` | 通过比较候选模型并识别统计等效的顶层来对表格数据进行分类。 |
| `matlab-create-experiment` | 通过分析用户代码并生成适当的函数和超参数来为试验管理器创建实验。 |
| `matlab-deploy-embedded-ai` | 使用 MATLAB 和 Simulink 将 AI 模型部署到嵌入式硬件。 |
| `matlab-engineer-tabular-features` | 为 MATLAB 中的单响应表格分类或回归进行特征工程并选择最佳特征。 |
| `matlab-fit-curve` | 使用曲线拟合器以交互方式拟合曲线和曲面。 |
| `matlab-import-external-ai-model` | 将 PyTorch、ONNX 和 Keras 深度学习模型导入 MATLAB 并验证数值正确性。 |
| `matlab-train-network` | 使用推荐的 API 训练、评估神经网络并将其导出到 Simulink。将旧版神经网络训练代码迁移到现代替代方案。 |
| `matlab-use-machine-learning-apps` | 使用分类学习器和回归学习器训练、比较和导出机器学习模型。 |

### 汽车 ([`automotive`](../../skills-catalog/automotive/))

支持 MATLAB、Simulink、Automated Driving Toolbox&trade;、Computer Vision Toolbox&trade;、RoadRunner、RoadRunner Scenario、RoadRunner Scene Builder、Sensor Fusion and Tracking Toolbox&trade;、Automated Driving Toolbox Interface for Eclipse SUMO Traffic Simulator&trade; 和 Scenario Builder for Automated Driving Toolbox&trade;

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-cosimulate-sumo-simulink` | 构建与 Eclipse&trade; SUMO 交通仿真器联合仿真的 Simulink 模型。 |
| `matlab-import-driving-data` | 将记录的驾驶传感器数据（GPS、摄像头、lidar、演员轨迹）导入 scenariobuilder.* 对象，并在场景构建之前同步、裁剪、偏移和规范化时间戳。 |
| `matlab-use-ncap-protocol` | 生成 Euro NCAP 测试场景和变体，在仿真器之间转换，并计算分数。 |
| `matlab-use-scenario-builder` | 从记录的传感器数据构建驾驶场景、道路表面和 3D 资产，并导出到 RoadRunner、drivingScenario、OpenSCENARIO、OpenDRIVE、OpenCRG 或 Unreal Engine&reg;。 |
| `roadrunner-asset-mapping` | 在 MATLAB 中为地图格式转换生成 RoadRunner 资产路径查找表。 |
| `roadrunner-build-scenario-from-osc` | 解释 OpenSCENARIO 1.x 文件并在 RoadRunner 中以编程方式重新创建场景。 |
| `roadrunner-convert-lanelet2-to-rrhd` | 使用 MATLAB 将 Lanelet2 地图 (.osm) 转换为 RoadRunner HD Map (.rrhd) 格式。 |
| `roadrunner-core` | 从 MATLAB 连接到 RoadRunner 并管理工程、场景和情景生命周期。 |
| `roadrunner-import-scene` | 连接到 RoadRunner 并使用 MATLAB 将 HD Map 或 OpenDRIVE 文件导入新场景。 |
| `roadrunner-rrhd-authoring` | 在 MATLAB 中构建 RoadRunner HD Map 实体：车道、边界、标线、交叉口、标志、信号灯、护栏、停车场。 |
| `roadrunner-scenario-authoring` | 从 MATLAB 以编程方式创建 RoadRunner 驾驶场景。 |
| `roadrunner-scenario-simulating` | 通过 MATLAB 和 Simulink 联合仿真以编程方式仿真 RoadRunner 场景。 |

### 云解决方案 ([`cloud-solutions`](../../skills-catalog/cloud-solutions/))

支持 MATLAB 和 MATLAB Drive&trade;

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-share-content` | 通过上传到 GitHub&reg;、MATLAB Drive 或 File Exchange 并生成“在 MATLAB Online&trade; 中打开”链接来共享 MATLAB 内容。 |

### 代码生成 ([`code-generation`](../../skills-catalog/code-generation/))

支持 MATLAB、Embedded Coder、Fixed-Point Designer、GPU Coder&trade;、MATLAB Coder、MATLAB Test&trade;、Parallel Computing Toolbox 和 MATLAB Coder Support Package for PyTorch and LiteRT Models&trade;

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-deploy-ai-model` | 使用 loadPyTorchExportedProgram、loadLiteRTModel 和 codegen 从 PyTorch ExportedProgram (.pt2) 或 LiteRT (.tflite) 模型生成 C/C++ 或 CUDA 代码。包括 Simulink 集成工作流。 |
| `matlab-deploy-embedded-code` | 通过 PIL 验证将 MATLAB 生成的代码部署到嵌入式硬件。 |
| `matlab-generate-code` | 使用 MATLAB Coder、Embedded Coder 或 GPU Coder 从 MATLAB 生成、验证和加速 C/C++ 或 CUDA 代码。 |
| `matlab-optimize-gpu-codegen` | 为 GPU Coder 优化 MATLAB 函数以生成更快的 CUDA 代码。 |
| `matlab-review-fi-object-code` | 审查 MATLAB 定点 (fi) 代码的性能、代码生成效率和正确性。 |

### 计算生物学 ([`computational-biology`](../../skills-catalog/computational-biology/))

支持 MATLAB、SimBiology&trade; 和 Statistics and Machine Learning Toolbox

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `simbiology-build-model` | 从头构建 SimBiology 模型、修改现有模型并生成图表布局。 |
| `simbiology-fit-model` | 将 SimBiology 模型参数拟合到数据。 |
| `simbiology-simulate-model` | 运行仿真、扫描参数、探索假设场景，并对 SimBiology 模型执行灵敏度分析。 |

### 计算金融 ([`computational-finance`](../../skills-catalog/computational-finance/))

支持 MATLAB、Datafeed Toolbox&trade;、Financial Instruments Toolbox&trade;、Financial Toolbox&trade; 和 Spreadsheet Link&trade;

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-access-datafeed` | 使用 Datafeed Toolbox 连接到 Bloomberg&reg;、FRED&reg;、Haver Analytics&reg; 和 LSEG&reg; Datastream 以检索金融和经济数据。 |
| `matlab-optimize-portfolio` | 构建和求解均值-方差投资组合优化问题。 |
| `matlab-price-instrument` | 使用蒙特卡罗、FFT 或利率树对金融工具进行定价。 |
| `matlab-use-spreadsheet-link` | 使用 Spreadsheet Link 编写 VBA 宏和工作表函数以与 Excel 交换数据。 |

### 控制系统 ([`control-systems`](../../skills-catalog/control-systems/))

支持 MATLAB、Control System Toolbox&trade;、Predictive Maintenance Toolbox&trade;、Signal Processing Toolbox&trade;、Statistics and Machine Learning Toolbox 和 System Identification Toolbox&trade;

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-extract-battery-features` | 从循环测试数据中提取电池特征，用于退化和健康分析。 |
| `matlab-extract-rotating-machinery-features` | 从旋转机械振动数据中提取特征，用于状态监测和故障检测。 |
| `matlab-identify-linear-system` | 使用 System Identification Toolbox 从测量数据中辨识线性动态模型。 |

### 图像处理和计算机视觉 ([`image-processing-and-computer-vision`](../../skills-catalog/image-processing-and-computer-vision/))

支持 MATLAB、Computer Vision Toolbox、Deep Learning Toolbox、Image Processing Toolbox&trade;、Lidar Toolbox&trade;、Medical Imaging Toolbox&trade; 和 Optical Design and Simulation Library for Image Processing Toolbox&trade;

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-analyze-spectral-images` | 读取、处理、分析、标注和分类高光谱和多光谱图像。 |
| `matlab-display-image` | 显示用于图像处理、计算机视觉和目视检查的图像和标注。 |
| `matlab-display-volume` | 显示用于 3D 图像处理的 3D 图像体积、医学图像体积、表面网格和标注。 |
| `matlab-integrate-pytorch-vision` | 使用 MPyReq 从 GitHub 存储库或 pip 包创建 Python 图像处理和计算机视觉模型的 MATLAB 接口。 |
| `matlab-model-optics` | 使用 Optical Design and Simulation Library 构建、导入、分析、优化光学系统和镀膜并进行公差分析。 |
| `matlab-process-large-images` | 使用 blockedImage 处理大型图像。 |
| `matlab-read-medical-data` | 使用 Image Processing Toolbox 和 Medical Imaging Toolbox API 读取、写入和操作医学影像数据（DICOM、NIfTI、NRRD）。 |
| `matlab-read-write-point-cloud-file` | 以 PLY、PCD、LAS/LAZ、PCAP、E57 和 IDC 格式读写 3D 点云数据。 |
| `matlab-recognize-text` | 使用 ocr() 函数在 MATLAB 中构建 OCR 管道。 |
| `matlab-register-point-clouds` | 使用 ICP、NDT、LOAM、FGR、相位相关和 CPD 算法对齐和配准 3D 点云。 |

### 数学和优化 ([`math-and-optimization`](../../skills-catalog/math-and-optimization/))

支持 MATLAB、Optimization Toolbox、Partial Differential Equation Toolbox&trade; 和 Symbolic Math Toolbox&trade;

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-solve-optimization` | 使用基于问题和基于求解器的方法来构建、求解和验证 MATLAB 优化问题。 |
| `matlab-solve-pde` | 使用 PDE Toolbox&trade; 为热、结构和电磁问题构建和求解有限元模型。 |
| `matlab-use-symbolic-math` | 使用 Symbolic Math Toolbox 生成正确的 MATLAB 代码，用于解析解、方程求解、微积分、变换和代码生成。 |

### 并行计算 ([`parallel-computing`](../../skills-catalog/parallel-computing/))

支持 MATLAB、Parallel Computing Toolbox 和 MATLAB Parallel Server&trade;

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-diagnose-parfor` | 诊断和修复 MATLAB 中的 parfor 变量分类错误。 |
| `matlab-discover-clusters` | 发现并行计算集群并管理集群配置文件。 |
| `matlab-set-up-worker-state` | 为并行池设置工作进程环境和每个工作进程的状态。 |
| `matlab-setup-gpu` | 检测和验证用于 MATLAB GPU 计算的 GPU 可用性。 |
| `matlab-use-thread-pool` | 使用基于线程的并行池加速本地并行计算。 |

### 雷达 ([`radar`](../../skills-catalog/radar/))

支持 MATLAB、Mapping Toolbox&trade;、Phased Array System Toolbox&trade;、Radar Toolbox&trade;、Sensor Fusion and Tracking Toolbox 和 Signal Processing Toolbox

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-design-radar-waveform` | 使用 Phased Array System Toolbox 设计、选择和分析雷达和声呐波形。 |
| `matlab-design-radar` | 在雷达设计器中设计、配置和分析雷达系统。 |
| `matlab-import-tracking-data` | 将原始跟踪数据（CSV、XLSX、TXT 或 MATLAB 表）导入 Sensor Fusion and Tracking Toolbox 使用的 objectDetection 数组和 objectTrack 数组。 |
| `matlab-simulate-radar-detections` | 为监视和跟踪雷达场景仿真统计雷达探测。 |

### 报告和数据库访问 ([`reporting-and-database-access`](../../skills-catalog/reporting-and-database-access/))

支持 MATLAB、Database Toolbox&trade;、MATLAB Report Generator、Parallel Computing Toolbox 和 Simulink Report Generator&trade;

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-connect-databricks` | 通过 Spark 或 JDBC 将 MATLAB 连接到 Databricks&reg; 以读写数据。 |
| `matlab-generate-report` | 使用 Report Generator API 从 MATLAB 数据和 Simulink 模型生成结构化的 PDF、Word 和 HTML 报告。 |
| `matlab-use-database` | 从 MATLAB 读取、写入、更新和管理关系数据库。 |
| `matlab-use-duckdb` | 将 DuckDB 作为大型表格文件的非数学运算引擎和零配置嵌入式数据库从 MATLAB 使用。包括预检路由、操作边界和配置-操作-关闭工作流。 |

### 射频和混合信号 ([`rf-and-mixed-signal`](../../skills-catalog/rf-and-mixed-signal/))

支持 MATLAB、Simulink、Antenna Toolbox&trade;、Mixed-Signal Blockset&trade;、RF Blockset&trade;、RF PCB Toolbox&trade;、RF Toolbox&trade;、SerDes Toolbox&trade;、Signal Integrity Toolbox、Signal Processing Toolbox 和 Statistics and Machine Learning Toolbox

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-analyze-ams-waveform` | 使用 Mixed-Signal Blockset 从 AMS 仿真波形中测量相位噪声、抖动和时序。 |
| `matlab-analyze-antenna-structures` | 设计和分析电大天线结构：反射器、反射阵、平台安装天线和雷达反射截面。 |
| `matlab-analyze-em` | 计算用于 RF PCB 性能验证的 S 参数、插入损耗、场和电流。 |
| `matlab-analyze-pcb-pdn` | 分析 PCB 布局上的 PDN DC 电压和电流分布、IR 压降和设计规则检查。 |
| `matlab-assemble-pcb-layout` | 使用 pcbComponent、形状、布尔运算、馈电和多层叠层构建自定义 PCB 结构。 |
| `matlab-design-antenna` | 使用 MATLAB Antenna Toolbox 设计天线、阵列和 PCB 天线。涵盖目录天线设计、自定义天线构建、PCB 天线设计、有限和无限阵列、AI 加速设计探索和优化。 |
| `matlab-design-pcb-coupler` | 设计 Wilkinson、branchline、ratrace 和定向耦合器、功分器和 Rotman 透镜。 |
| `matlab-design-pcb-filter` | 使用 hairpin、耦合线、combline、stub 和 SIW 拓扑设计带通、低通和带阻 RF 滤波器。 |
| `matlab-design-pcb-passive` | 设计 RF 电路用螺旋电感器、交指电容器、巴伦、谐振器和移相器。 |
| `matlab-design-pcb-transmission-line` | 设计带阻抗控制和串扰分析的微带线、带状线、CPW 和差分对传输线。 |
| `matlab-export-session-script` | 将对话 MATLAB 代码导出为干净、可运行的 .m 脚本。 |
| `matlab-integrate-antenna` | 使用 MATLAB Antenna Toolbox 和 RF Toolbox 将天线集成到 RF 系统中。涵盖阻抗匹配网络设计、测量天线创建、RF 传播和站点规划以及 SAR 估算。 |
| `matlab-integrate-pcb-circuit` | 级联 PCB 组件、添加集总元件并导出多组件 RF 电路的 Touchstone 文件。 |
| `matlab-manage-pcb-material` | 定义 RF PCB 仿真的介质基板、金属导体、多层叠层和损耗模型。 |
| `matlab-model-ams-systems` | 使用 Mixed-Signal Blockset 从 IC 数据表或系统规格建模 PLL 频率合成器。提取参数、选择架构、组装 Simulink 模型、设计环路滤波器、验证相位噪声。 |
| `matlab-model-rf` | 使用 RF Toolbox 和 RF Blockset 在 MATLAB 中设计、分析和仿真 RF 系统 -- 从 S 参数 I/O 到完整的 Circuit Envelope 时域仿真。 |
| `matlab-model-serdes-systems` | 使用 MATLAB SerDes Toolbox 建模、仿真和优化串行器/解串器 (SerDes) 系统 — 串行和并行链路。 |
| `matlab-model-via` | 为高速 PCB 层间过渡建模包含焊盘、反焊盘和接地回流过孔的过孔。 |
| `matlab-optimize-pcb-design` | 使用 patternsearch 和 surrogateopt 优化 RF PCB 组件尺寸以满足带宽、回波损耗或面积要求。 |
| `matlab-read-pcb-layout` | 导入 Gerber、ODB++ 和 Allegro .brd 文件并检查网络、层、形状和叠层。 |
| `matlab-write-pcb-layout` | 将 pcbComponent 设计导出为 Gerber 文件以用于 PCB 制造。 |

### 机器人和自主系统 ([`robotics-and-autonomous-systems`](../../skills-catalog/robotics-and-autonomous-systems/))

支持 MATLAB、Navigation Toolbox&trade;、UAV Toolbox&trade; 和 Robotics System Toolbox&trade;

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-compute-gnss-position` | 使用 rinexread、gnssmeasurements、receiverposition 和 gnssoptions 从 RINEX v3 数据计算多星座 GPS 或 GNSS 位置。 |
| `matlab-connect-mavlink` | 在 MATLAB 和 PX4 或 ArduPilot 飞行控制器之间建立 MAVLink 连接。 |
| `matlab-create-uav-scenario` | 创建和仿真包含地形、建筑物、搭载传感器的平台和 3D 可视化的 UAV 场景。 |
| `matlab-fuse-inertial-sensors` | 分析传感器配置并在 MATLAB Navigation Toolbox 中创建惯性融合滤波器。 |
| `matlab-model-robot-kinematics` | 构建机械臂模型并在 MATLAB 中验证运动学解。 |
| `matlab-plan-robot-motion` | 规划无碰撞机械臂运动并生成时间参数化轨迹。 |

### 信号处理 ([`signal-processing`](../../skills-catalog/signal-processing/))

支持 MATLAB、Simulink、Audio Toolbox&trade;、DSP HDL Toolbox&trade;、DSP System Toolbox&trade;、Fixed-Point Designer、HDL Coder&trade;、Signal Processing Toolbox 和 Wavelet Toolbox&trade;

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-analyze-spectrum` | 使用非参数和参数估计器分析信号频谱。 |
| `matlab-analyze-time-frequency-content` | 使用 CWT、STFT、synchrosqueezing 和小波相干性分析时频内容。 |
| `matlab-configure-scope-object` | 配置示波器相关 Simulink 模块或 MATLAB 对象的属性。 |
| `matlab-design-adaptive-filter` | 使用 System object 设计和实现自适应滤波器。 |
| `matlab-design-digital-filter` | 在 MATLAB 中设计和验证数字滤波器。 |
| `matlab-design-dsphdl-ddc` | 使用 dsphdl System object 设计 HDL 优化的数字下变频器。 |
| `matlab-extract-signal-features` | 从 1D 信号中提取每帧的时域、频域和时频特征。 |
| `matlab-play-record-audio` | 使用 audiostreamer 在 MATLAB 中播放和录制音频。 |
| `matlab-prepare-signal-data` | 对原始信号进行预处理（填充空隙、去趋势、去异常值、去噪、重采样/对齐），并为 ML 训练构建 signalDatastore 管道（标签、分层拆分、分帧、并行读取和 trainnet 传递）。 |
| `matlab-process-streaming-audio` | 使用 Audio Toolbox 流式对象设计和运行实时音频处理链。 |
| `matlab-write-audio-plugin` | 创建通过 validateAudioPlugin 和 generateAudioPlugin 编译为 VST/AU 的 Audio Toolbox 插件。 |

### 测试和测量 ([`test-and-measurement`](../../skills-catalog/test-and-measurement/))

支持 MATLAB、Data Acquisition Toolbox&trade;、Image Acquisition Toolbox&trade;、Image Processing Toolbox、Industrial Communication Toolbox&trade;、Vehicle Network Toolbox&trade; 和 MATLAB Support Package for Arduino Hardware&trade;

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-build-industrial-hmi` | 按照 ISA-101 规范在 MATLAB 中构建工业级 SCADA/HMI 仪表板。在 matlab-build-app 可用时将序列化委托给它以生成真正的 App 设计工具应用程序 (.mlapp)，否则回退到编程式 .m 应用程序。 |
| `matlab-call-nidaqmx` | 将 NI-DAQmx C 函数转换为正确的 MATLAB calldaqlib 调用。 |
| `matlab-connect-arduino` | 通过 USB 从 MATLAB 发现、配置和连接 Arduino&reg; 开发板。 |
| `matlab-connect-bluetooth-low-energy-device` | 从 MATLAB 发现并连接 Bluetooth Low Energy 外围设备。 |
| `matlab-create-custom-arduino-library` | 创建自定义 Arduino 附加功能库以从 MATLAB 访问不支持的传感器和外围设备。 |
| `matlab-discover-hardware` | 通过辅助函数发现、检查和设置 MATLAB 支持的硬件设备。 |
| `matlab-enhance-camera-image` | 诊断并增强通过 Image Acquisition Toolbox 连接的摄像头的图像质量。 |
| `matlab-find-pi-assets` | 使用 piclient 和 afclient 查找和查询 PI Data Archive 标签和 Asset Framework 元素。 |
| `matlab-import-export-vehicle-data` | 从日志文件（ASC、BLF、MDF、DAT、TXT）导入、解码和导出车辆网络数据，正确处理多态返回类型、CAN/CAN FD/LIN 解码管道和 MDF/BLF 写入工作流。 |
| `matlab-modernize-daq` | 将旧版基于会话的 Data Acquisition Toolbox 代码迁移到现代 DataAcquisition 接口。 |
| `matlab-use-cameras` | 使用 Image Acquisition Toolbox videoinput 接口连接摄像头并采集图像。 |
| `matlab-use-opcua-client` | 发现 OPC UA 服务器，在 MATLAB 中创建安全的客户端连接，并浏览和导航服务器节点。 |
| `matlab-use-vehicle-network` | 在所有支持的硬件供应商上使用 Vehicle Network Toolbox 在 MATLAB 中设置、排除故障和分析 CAN/CAN FD 车辆网络通信。 |

### 无线通信 ([`wireless-communications`](../../skills-catalog/wireless-communications/))

支持 MATLAB、5G Toolbox&trade;、Bluetooth&reg; Toolbox&trade;、Communications Toolbox&trade;、Satellite Communications Toolbox&trade;、Wireless Network Toolbox&trade;、Wireless Testbench&trade;、WLAN Toolbox&trade; 和 Wireless Testbench Support Package for NI USRP Radios&trade;

| 技能 | 教给智能体的内容 |
|-------|---------------------------|
| `matlab-add-awgn` | 添加加性高斯白噪声 (AWGN) 并在通信仿真中转换 SNR、Eb/No、Es/No 和每子载波 SNR。 |
| `matlab-design-ofdm-system` | 使用 ofdmmod/ofdmdemod 设计和仿真自定义 OFDM 系统，包含衰落信道配置、均衡、同步（定时/CFO）、LDPC 编码、SNR 处理、子载波分配和基于导频的信道估计。 |
| `matlab-generate-5g-waveform` | 生成符合 3GPP 的 5G NR 下行链路和上行链路基带波形。 |
| `matlab-generate-ble-waveform` | 生成和分析 Bluetooth Low Energy PHY 波形。 |
| `matlab-generate-gnss-waveform` | 使用 Satellite Communications Toolbox 生成具有物理真实或用户指定信道损伤的 GNSS 基带波形（GPS、Galileo、NavIC）。 |
| `matlab-generate-wlan-waveform` | 生成符合 IEEE 802.11 标准的 WLAN 波形。 |
| `matlab-set-up-usrp-radio` | 设置和验证用于 Wireless Testbench 的 NI USRP 射频设备。 |
| `matlab-simulate-bluetooth-network` | 仿真包括 BLE、Classic BR/EDR 和 LE Audio 在内的 Bluetooth 系统级网络。 |
| `matlab-simulate-wireless-network` | 使用 wirelessNetworkSimulator 设置和运行无线网络仿真。 |
| `matlab-transmit-capture-usrp` | 使用 NI USRP 射频设备和 Wireless Testbench 发射和捕获 RF 波形。 |

<!-- END SKILLS -->

## 技能的安装方式

有关这些技能安装方式的详细信息，请参阅[安装 MATLAB Agentic Toolkit](../README.zh-cn.md#安装-matlab-agentic-toolkit)

----

Copyright 2026 The MathWorks, Inc.

----
