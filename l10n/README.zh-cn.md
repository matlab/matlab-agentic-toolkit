<!--
Source English Markdown:
- File: ./README.md
- Branch: main
- Commit: 645cf259dedf8b012f89fdb7006ad7c1afa33e3e
-->

# MATLAB Agentic Toolkit

<p align="center">
  <a href="../README.md">English</a> •
  <a href="README.es.md">Español</a> •
  <a href="README.ja.md">日本語</a> •
  <a href="README.ko.md">한국어</a> •
  简体中文
</p>

[![Latest Release](https://img.shields.io/github/v/release/matlab/matlab-agentic-toolkit?cacheSeconds=1800)](https://github.com/matlab/matlab-agentic-toolkit/releases/latest)
[![Release Date](https://img.shields.io/github/release-date/matlab/matlab-agentic-toolkit?cacheSeconds=1800)](https://github.com/matlab/matlab-agentic-toolkit/releases/latest)

MATLAB&reg; Agentic Toolkit 允许您通过为 AI 智能体提供高效使用 MATLAB 及其工具箱所需的知识和上下文，将 AI 智能体与 MATLAB 配合使用。使用此工具包为您的智能体提供可信赖的 MATLAB 功能。此工具包可以防止您的 AI 智能体虚构工具箱函数、遗漏新功能，以及在经验丰富的 MATLAB 用户会跳过的额外步骤上浪费时间。

使用此工具包可以：

- 将您的 AI 智能体连接到 MATLAB。此工具包通过自动安装 [MATLAB MCP Server](https://github.com/matlab/matlab-mcp-server) 来实现此功能。然后，您可以使用智能体编写符合 MATLAB 惯例的代码、生成和运行测试、诊断错误、构建应用程序等。

- 为您的智能体提供精选的专业知识（技能）。这些技能为您的智能体提供 MATLAB 工作流、约定和最佳实践方面的知识，同时最大限度地减少词元消耗。

> [!Note]
> 如果仅将 AI 智能体用于 Simulink&reg;，请安装 [Simulink Agentic Toolkit](https://github.com/matlab/simulink-agentic-toolkit)。如需安装两个工具包，请使用 [Agentic Toolkit Installer](#安装-matlab-agentic-toolkit)。


## 要求

* MATLAB R2021a 或更高版本
* 支持 MCP 服务器和技能的 AI 编码智能体。受支持的智能体会自动配置。否则，请参阅您的智能体文档以手动配置 MCP 服务器和安装技能。受支持的智能体包括：
    - Claude Code
    - GitHub&reg; Copilot
    - OpenAI&reg; Codex
    - Gemini&trade; CLI
    - Amp

---
## 开始使用 MATLAB Agentic Toolkit

以下步骤展示了如何使用 MATLAB Agentic Toolkit 安装 MATLAB MCP Server 并向您的智能体添加技能。

> 注意：有关从本地文件安装、在离线环境中安装、此工具包的配置设置选项、平台特定说明、验证步骤、故障排除以及不使用安装程序的手动设置的说明，请参阅[配置和故障排除](../Configuration_and_Troubleshooting.md)。如果您已安装 MCP 服务器且只需要添加技能，请参阅[仅添加技能](../Configuration_and_Troubleshooting.md#adding-skills-only)。

### 安装 MATLAB Agentic Toolkit

按照以下步骤设置 MATLAB Agentic Toolkit。

1. 要下载安装程序，请单击 [agenticToolkitInstaller.mltbx](https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx)。
2. 使用 MATLAB 打开下载的文件以安装安装程序附加功能。
3. 在 MATLAB 中运行以下命令。

```matlab
setupAgenticToolkit("install")
```

4. 仅安装与您的工作相关的技能组。这有助于您的智能体可靠地触发正确的技能。如需添加更多技能组，请重新运行安装程序。
5. 默认情况下，您的智能体在调用时会创建一个新的 MATLAB 会话。要将智能体连接到现有的 MATLAB 会话，请在 MATLAB 命令行窗口中运行以下命令。

```
shareMATLABSession()
```

如果您正在运行多个 MATLAB 会话，智能体将连接到您最近运行此命令的 MATLAB 会话。

或者，您也可以将此命令添加到 MATLAB [启动脚本](https://www.mathworks.com/help/matlab/ref/startup.html)中。


### 验证
向您的智能体提问：

```
目前运行的是哪个版本的 MATLAB？请列出已安装的工具箱。
```

### 使用 MCP 工具运行和测试 MATLAB 代码
安装 MATLAB Agentic Toolkit 后，您的智能体可以使用 MATLAB MCP Server 提供的以下工具。

| 您可以要求智能体执行的任务 | 智能体使用的工具 |
|------|------------------------|
| 运行 MATLAB 代码并返回命令行窗口输出 | `evaluate_matlab_code` |
| 运行 MATLAB 程序 | `run_matlab_file` |
| 通过 `runtests` 运行测试并获取结构化结果 | `run_matlab_test_file`|
| 使用代码分析器进行静态代码分析 | `check_matlab_code` |
| 列出已安装的 MATLAB 版本和工具箱 | `detect_matlab_toolboxes` |

服务器还提供两个 MCP 资源：`matlab_coding_guidelines`（编码标准）和 `plain_text_live_code_guidelines`（实时脚本格式规则）。这些资源提供了智能体可以按需读取的参考信息。

### 使用智能体技能运行 MATLAB 工作流
安装 MATLAB Agentic Toolkit 后，您的智能体可以使用 MathWorks&reg; 精选的技能。为获得最佳效果，请仅安装与您的工作相关的技能组，加载的技能越少，智能体触发技能就越可靠。您也可以按名称手动触发特定技能（例如，在 Claude Code 中使用 `/matlab-write-tests`）以确保其加载。要阅读所有技能的详细信息，请参阅[技能目录](skills-catalog/README.zh-cn.md)。技能组包括：

<!-- BEGIN SKILLS -->
#### MATLAB 技能

| 技能组 | 描述 |
|-------------|-------------|
| [**MATLAB 核心**](skills-catalog/README.zh-cn.md#matlab-核心-matlab-core) | 创建、调试、测试、审查和管理 MATLAB 代码及安装 |
| [**MATLAB App 构建**](skills-catalog/README.zh-cn.md#matlab-app-构建-matlab-app-building) | 使用 UI 组件、布局、回调和 Web 集成以编程方式构建 MATLAB 应用程序 |
| [**MATLAB 数据导入和分析**](skills-catalog/README.zh-cn.md#matlab-数据导入和分析-matlab-data-import-and-analysis) | 使用表、timetable、筛选、聚合和时间序列操作在 MATLAB 中导入、导出和分析数据 |
| [**MATLAB 环境和设置**](skills-catalog/README.zh-cn.md#matlab-环境和设置-matlab-environment-and-settings) | 比较不同版本之间的 MATLAB 设置差异，并将启动脚本迁移到正确的设置路径 |
| [**MATLAB 外部语言接口**](skills-catalog/README.zh-cn.md#matlab-外部语言接口-matlab-external-language-interfaces) | 从 MATLAB 调用 Python&reg; 库并将 MEX 文件升级到 interleaved complex API |
| [**MATLAB 编程**](skills-catalog/README.zh-cn.md#matlab-编程-matlab-programming) | 编写具有经过验证的输入的稳健 MATLAB 函数 |
| [**MATLAB 软件开发**](skills-catalog/README.zh-cn.md#matlab-软件开发-matlab-software-development) | 现代化遗留代码、优化性能和内存、编写文档和创建工具箱、创建工程和制定构建计划 |

#### 工具箱技能

| 技能组 | 支持的产品 |
|-------------|--------------------|
| [**航空航天**](skills-catalog/README.zh-cn.md#航空航天-aerospace) | MATLAB 和 Aerospace Toolbox&trade; |
| [**AI 和统计**](skills-catalog/README.zh-cn.md#ai-和统计-ai-and-statistics) | MATLAB、Simulink、Curve Fitting Toolbox&trade;、Deep Learning Toolbox&trade;、Embedded Coder&trade;、Fixed-Point Designer&trade;、MATLAB Coder&trade;、MATLAB Compiler SDK&trade;、MATLAB Report Generator&trade;、Optimization Toolbox&trade;、Parallel Computing Toolbox&trade;、Statistics and Machine Learning Toolbox&trade;、Deep Learning Toolbox Converter for ONNX Model Format&trade;、Deep Learning Toolbox Converter for PyTorch Models&trade; 和 Deep Learning Toolbox Converter for TensorFlow Models&trade; |
| [**汽车**](skills-catalog/README.zh-cn.md#汽车-automotive) | MATLAB、Simulink、Automated Driving Toolbox&trade;、Computer Vision Toolbox&trade;、RoadRunner、RoadRunner Scenario、RoadRunner Scene Builder、Sensor Fusion and Tracking Toolbox&trade;、Automated Driving Toolbox Interface for Eclipse SUMO Traffic Simulator&trade; 和 Scenario Builder for Automated Driving Toolbox&trade; |
| [**云解决方案**](skills-catalog/README.zh-cn.md#云解决方案-cloud-solutions) | MATLAB 和 MATLAB Drive&trade; |
| [**代码生成**](skills-catalog/README.zh-cn.md#代码生成-code-generation) | MATLAB、Embedded Coder、Fixed-Point Designer、GPU Coder&trade;、MATLAB Coder、MATLAB Test&trade;、Parallel Computing Toolbox 和 MATLAB Coder Support Package for PyTorch and LiteRT Models&trade; |
| [**计算生物学**](skills-catalog/README.zh-cn.md#计算生物学-computational-biology) | MATLAB、SimBiology&trade; 和 Statistics and Machine Learning Toolbox |
| [**计算金融**](skills-catalog/README.zh-cn.md#计算金融-computational-finance) | MATLAB、Datafeed Toolbox&trade;、Financial Instruments Toolbox&trade;、Financial Toolbox&trade; 和 Spreadsheet Link&trade; |
| [**控制系统**](skills-catalog/README.zh-cn.md#控制系统-control-systems) | MATLAB、Control System Toolbox&trade;、Predictive Maintenance Toolbox&trade;、Signal Processing Toolbox&trade;、Statistics and Machine Learning Toolbox 和 System Identification Toolbox&trade; |
| [**图像处理和计算机视觉**](skills-catalog/README.zh-cn.md#图像处理和计算机视觉-image-processing-and-computer-vision) | MATLAB、Computer Vision Toolbox、Deep Learning Toolbox、Image Processing Toolbox&trade;、Lidar Toolbox&trade;、Medical Imaging Toolbox&trade; 和 Optical Design and Simulation Library for Image Processing Toolbox&trade; |
| [**数学和优化**](skills-catalog/README.zh-cn.md#数学和优化-math-and-optimization) | MATLAB、Optimization Toolbox、Partial Differential Equation Toolbox&trade; 和 Symbolic Math Toolbox&trade; |
| [**并行计算**](skills-catalog/README.zh-cn.md#并行计算-parallel-computing) | MATLAB、Parallel Computing Toolbox 和 MATLAB Parallel Server&trade; |
| [**雷达**](skills-catalog/README.zh-cn.md#雷达-radar) | MATLAB、Mapping Toolbox&trade;、Phased Array System Toolbox&trade;、Radar Toolbox&trade;、Sensor Fusion and Tracking Toolbox 和 Signal Processing Toolbox |
| [**报告和数据库访问**](skills-catalog/README.zh-cn.md#报告和数据库访问-reporting-and-database-access) | MATLAB、Database Toolbox&trade;、MATLAB Report Generator、Parallel Computing Toolbox 和 Simulink Report Generator&trade; |
| [**射频和混合信号**](skills-catalog/README.zh-cn.md#射频和混合信号-rf-and-mixed-signal) | MATLAB、Simulink、Antenna Toolbox&trade;、Mixed-Signal Blockset&trade;、RF Blockset&trade;、RF PCB Toolbox&trade;、RF Toolbox&trade;、SerDes Toolbox&trade;、Signal Integrity Toolbox、Signal Processing Toolbox 和 Statistics and Machine Learning Toolbox |
| [**机器人和自主系统**](skills-catalog/README.zh-cn.md#机器人和自主系统-robotics-and-autonomous-systems) | MATLAB、Navigation Toolbox&trade;、UAV Toolbox&trade; 和 Robotics System Toolbox&trade; |
| [**信号处理**](skills-catalog/README.zh-cn.md#信号处理-signal-processing) | MATLAB、Simulink、Audio Toolbox&trade;、DSP HDL Toolbox&trade;、DSP System Toolbox&trade;、Fixed-Point Designer、HDL Coder&trade;、Signal Processing Toolbox 和 Wavelet Toolbox&trade; |
| [**测试和测量**](skills-catalog/README.zh-cn.md#测试和测量-test-and-measurement) | MATLAB、Data Acquisition Toolbox&trade;、Image Acquisition Toolbox&trade;、Image Processing Toolbox、Industrial Communication Toolbox&trade;、Vehicle Network Toolbox&trade; 和 MATLAB Support Package for Arduino Hardware&trade; |
| [**无线通信**](skills-catalog/README.zh-cn.md#无线通信-wireless-communications) | MATLAB、5G Toolbox&trade;、Bluetooth&reg; Toolbox&trade;、Communications Toolbox&trade;、Satellite Communications Toolbox&trade;、Wireless Network Toolbox&trade;、Wireless Testbench&trade;、WLAN Toolbox&trade; 和 Wireless Testbench Support Package for NI USRP Radios&trade; |
<!-- END SKILLS -->
---
## 更新 MATLAB Agentic Toolkit

要更新工具包，请单击 [agenticToolkitInstaller.mltbx](https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx) 下载最新的安装程序附加功能。使用 MATLAB 打开下载的文件，然后在 MATLAB 中运行以下命令。

```matlab
setupAgenticToolkit("update")
```

这将更新 MATLAB 和 Simulink Agentic Toolkit 的技能、配置和 MCP 服务器二进制文件。

---
## 安全注意事项
使用 MATLAB Agentic Toolkit 和 MATLAB MCP Server 时，您应在运行所有工具调用之前对其进行彻底审查和验证。对于重要操作，请始终保持人员在环，并仅在确信调用将完全按照预期执行时才继续。有关详细信息，请参阅 [User Interaction Model (MCP)](https://modelcontextprotocol.io/specification/latest/server/tools#user-interaction-model) 和 [Security Considerations (MCP)](https://modelcontextprotocol.io/specification/latest/server/tools#security-considerations)。

---
## 数据收集

MATLAB MCP Server 默认收集匿名使用数据。有关完整详细信息，请参阅 MCP 服务器文档中的[数据收集](https://github.com/matlab/matlab-mcp-server/blob/main/l10n/README.zh-cn.md#数据收集)。要选择退出，请参阅[禁用数据收集](../Configuration_and_Troubleshooting.md#disable-data-collection)。

---
## 许可和使用
许可包含在此 GitHub 仓库的 [LICENSE.md](../LICENSE.md) 文件中。

MCP 服务器仅允许在遵守《MathWorks 软件许可协议》的前提下与 MATLAB 配合使用，且不得由多个用户共享。如果您需要支持共享或集中式服务器使用，请联系 MathWorks。

---
## 支持和贡献
MathWorks 鼓励您使用此存储库并提供反馈。此存储库未启用拉取请求。要请求技术支持或提交增强请求，请[创建 GitHub issue](https://github.com/matlab/matlab-agentic-toolkit/issues) 或[联系技术支持](https://www.mathworks.com/support/contact_us.html)。


----

Copyright 2026 The MathWorks, Inc.

----
