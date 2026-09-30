<!--
Source English Markdown:
- File: ./Configuration_and_Troubleshooting.md
- Branch: main
- Commit: 645cf259dedf8b012f89fdb7006ad7c1afa33e3e
-->

# 配置和故障排除

<p align="center">
  <a href="../Configuration_and_Troubleshooting.md">English</a> •
  <a href="Configuration_and_Troubleshooting.es.md">Español</a> •
  <a href="Configuration_and_Troubleshooting.ja.md">日本語</a> •
  <a href="Configuration_and_Troubleshooting.ko.md">한국어</a> •
  简体中文
</p>

本页介绍如何配置 MATLAB&reg; Agentic Toolkit。有关 MATLAB Agentic Toolkit 的概述，请参阅 [README](README.zh-cn.md)。

## 要求

- MATLAB R2021a 或更高版本
- 支持 MCP 服务器和技能的 AI 编码智能体。支持的智能体会自动配置。否则，请参阅智能体的文档并手动配置 MCP 服务器以及安装技能。支持的智能体包括:
  - Claude Code
  - GitHub&reg; Copilot
  - OpenAI&reg; Codex
  - Gemini&trade; CLI
  - Amp

---

## 从本地文件安装 (离线计算机)

要在离线或隔离环境中安装 MATLAB Agentic Toolkit，请先在有互联网访问权限的计算机上下载以下工件，然后将其传输到目标计算机或共享位置。

| 工件 | 获取位置 |
|----------|----------------|
| MCP 服务器二进制文件 | [MATLAB MCP Server latest release](https://github.com/matlab/matlab-mcp-server/releases/latest) — 下载适用于您平台的二进制文件 (例如 `matlab-mcp-server-macos-arm64`、`matlab-mcp-server-windows-x64.exe`)。 |
| MCP 服务器工具箱 | [MATLAB MCP Server latest release](https://github.com/matlab/matlab-mcp-server/releases/latest) — 下载 `MATLABMCPServerToolbox.mltbx`。 |
| Agentic Toolkit 安装程序 | [Simulink Agentic Toolkit latest release](https://github.com/matlab/simulink-agentic-toolkit/releases/latest) — 下载 `agenticToolkitInstaller.mltbx`。 |
| MATLAB Agentic Toolkit | 从 [GitHub](https://github.com/matlab/matlab-agentic-toolkit) 克隆或下载。 |
| Simulink Agentic Toolkit | 从 [GitHub](https://github.com/matlab/simulink-agentic-toolkit) 克隆或下载。仅在安装 Simulink Agentic Toolkit 时才需要。|

下载这些工件后，在 MATLAB 中打开 `agenticToolkitInstaller.mltbx` 以安装附加功能。
在 MATLAB 中，使用以下名称-值参量在命令行窗口中运行 `setupAgenticToolkit` 命令。

| 参量 | 值 |
|----------|-----------------|
| `MCPServerLocation` | MCP 服务器二进制文件的下载路径 |
| `MCPToolboxLocation` | MATLAB 工具箱 (`.mltbx`) 的下载路径 |
| `MATLABAgenticToolkitLocation` | MATLAB Agentic Toolkit 存储库的克隆路径 |
| `SimulinkAgenticToolkitLocation` | Simulink Agentic Toolkit 存储库的克隆路径 |

安装程序会下载您未在本地提供的工件。要阻止互联网访问并在工件不可用时报告错误，请设置 `Offline=true`。例如，使用以下命令从本地文件安装 MATLAB Agentic Toolkit。

```matlab
setupAgenticToolkit("install", Offline=true,  ...
    MCPServerLocation="/shared/agentic-toolkits/bin/matlab-mcp-server-linux-x64", ...
    MCPToolboxLocation="/shared/agentic-toolkits/toolboxes/MATLABMCPServerToolbox.mltbx", ...
    MATLABAgenticToolkitLocation="/shared/agentic-toolkits/matlab-agentic-toolkit")
```

---

## 使用智能体安装 MATLAB

如果您尚未安装 MATLAB，可以按照以下步骤使用 AI 智能体来安装 MATLAB。
1) 按照[仅添加技能](#adding-skills-only)中的步骤安装 MATLAB Agentic Toolkit 技能。
2) 让智能体使用 `matlab-install-products` 技能安装 MATLAB。

安装 MATLAB 后，您可以通过按照 [Agentic Toolkit 安装程序](README.zh-cn.md#安装-matlab-agentic-toolkit)中的说明自动安装 MATLAB MCP Server，或者通过手动安装和配置 MATLAB MCP Server 来完成 MATLAB Agentic Toolkit 设置。

---

## 安装并配置 MCP 服务器

要手动安装和配置 MCP 服务器而不使用自动设置，请参阅 [MATLAB MCP Server](https://github.com/matlab/matlab-mcp-core-server) GitHub 存储库中的说明。安装 MCP 服务器后，将智能体的 MCP 配置指向已安装的二进制文件。请参阅此表格了解配置文件位置，或参阅智能体的文档。

| 平台 | MCP 配置 | 平台特定说明 |
|----------|------------------|-------------------|
| Claude Code | `~/.claude.json` | 使用 `claude mcp add` 进行配置。 |
| GitHub Copilot | VS Code 用户配置文件 `mcp.json` | 设置完成后重新加载 VS Code。 |
| OpenAI Codex | `~/.codex/config.toml` | 设置完成后，您可以在 `~/.codex/config.toml` 的 `[mcp_servers.matlab]` 部分调整两个设置: 1) 设置 `tool_timeout_sec = 600` 以增加较长时间的 MATLAB 操作 (例如测试套件和仿真) 的工具超时时长。对于运行时间非常长的任务，进一步增加此值。2) 在 Windows&reg; 上设置 `env_vars = ['WINDIR']` 以使 Simulink&reg; 正常工作，因为 Codex 默认会从 MCP 服务器子进程中剥离环境变量。 |
| Gemini CLI | `~/.gemini/settings.json` | 设置完成后启动新的 Gemini 会话。 |
| Amp | `~/.config/amp/settings.json` | 如果您有阻止 MCP 服务器的 `amp.mcpPermissions` 规则，请为 MATLAB 服务器添加允许规则。 |

---

## 禁用数据收集

MATLAB MCP Server 会收集有关您使用服务器情况的完全匿名信息，并将其发送到 MathWorks&reg;。此数据收集有助于 MathWorks 改进产品，并且默认情况下已启用。要选择退出数据收集，请通过在 MATLAB 中运行以下命令，将工具包的 `DisableTelemetry` 选项设为 `true`:

```matlab
setupAgenticToolkit("configure", DisableTelemetry=true)
```

此命令会使每个已配置的智能体退出数据收集。当您使用 `setupAgenticToolkit("update")` 更新工具包时，此设置会保留。如果您通过运行 `setupAgenticToolkit("configure")` 为智能体重新配置工具包，请再次包含 `DisableTelemetry=true` 以保持数据收集处于禁用状态。

---

<a id="adding-skills-only"></a>
## 仅添加技能

如果您已有 MATLAB MCP Server，则只需要技能。技能存放在 `skills-catalog/` 下的文件夹中，称为技能组。您必须安装 `matlab-core` 技能组。要获取额外的领域专业知识，您可以单独安装其他特定技能组。仅安装您需要的技能，以便智能体可靠地触发这些技能。要确保在您的工作流中加载特定技能，您也可以使用其名称手动触发该技能。

有关技能组和技能的详情，请参阅 [`skills-catalog/` README](skills-catalog/README.zh-cn.md)。

### Claude Code

每个技能组都作为 Claude Code 插件提供。要添加技能组，请先添加市场，然后安装 `matlab-core` 技能组。

```bash
claude plugin marketplace add "https://github.com/matlab/matlab-agentic-toolkit"
claude plugin install matlab-core@matlab-agentic-toolkit
```

安装 `matlab-core` 技能组后，使用相同的模式和该技能组的目录名来安装特定的技能组。

```bash
claude plugin install <group-name>@matlab-agentic-toolkit
```

例如，要添加信号处理和无线通信技能:

```bash
claude plugin install signal-processing@matlab-agentic-toolkit
claude plugin install wireless-communications@matlab-agentic-toolkit
```

在提示时选择您首选的范围 (按工程、按用户或全局)。您现有的 MCP 配置不会被修改。


### GitHub Copilot、OpenAI Codex、Gemini CLI

大多数其他 AI 智能体从 `~/.agents/skills/` 发现技能。要将技能添加到您的智能体，您必须从 `~/.agents/skills/` 文件夹设置到各个技能组的符号链接。首先，克隆工具包。

```bash
git clone https://github.com/matlab/matlab-agentic-toolkit.git
```

克隆工具包后，为您想要的每个组创建符号链接。将 `/path/to/matlab-agentic-toolkit` 替换为工具包克隆的实际路径，并列出您需要的技能组。例如，使用以下命令安装 `matlab-core` 和 `signal-processing`。

```bash
mkdir -p ~/.agents/skills
for group in matlab-core signal-processing; do
  for skill in /path/to/matlab-agentic-toolkit/skills-catalog/$group/*/; do
    ln -s "$skill" ~/.agents/skills/$(basename "$skill")
  done
done
```

或者，对于 Gemini，您可以通过将工具包作为 Gemini CLI 扩展程序安装来添加技能。
  ```bash
 gemini extensions install https://github.com/matlab/matlab-agentic-toolkit
  ```

### Amp

Amp 从 `~/.config/amp/settings.json` 中列出的路径读取技能。首先，克隆工具包。

```bash
git clone https://github.com/matlab/matlab-agentic-toolkit.git
```

克隆工具包后，为您想要的每个组添加一个 `skills-catalog/<group>` 路径条目。

```json
{
  "amp.skills.path": [
    "/path/to/matlab-agentic-toolkit/skills-catalog/matlab-core",
    "/path/to/matlab-agentic-toolkit/skills-catalog/signal-processing"
  ]
}
```

---

## 验证

### 检查技能是否已加载

如果您的智能体可在其 UI 中显示已加载的技能或插件 (例如 Claude Code 的 `/skills` 命令)，请确认 MATLAB Agentic Toolkit 技能已列出。

### 试试看

问问智能体:

```
当前运行的是哪个版本的 MATLAB？列出已安装的工具箱。
```

智能体使用 MCP 调用 `detect_matlab_toolboxes` 并报告 MATLAB 版本和可用的工具箱。

### 更多示例

```
编写一个计算信号移动平均值的函数，并为其生成单元测试。
```

```
审查 myScript.m 文件的代码质量问题，并提供改进建议。
```

```
创建一个纯文本实时脚本，使用样本数据演示曲线拟合。
```
---

## 按工程配置

当您使用顶层 [README](README.zh-cn.md) 上的自动设置安装 MATLAB Agentic toolkit 时，工具包是全局配置的。MATLAB 工具和技能在每个会话中都可用，无论您打开哪个工程。

您也可以在工程级别配置 MCP 服务器。这样您可以将工具和技能仅限于需要它们的工程。当配置提交到版本控制时，它也会帮助您的团队，因为任何克隆存储库的人都会自动获取 MATLAB 连接 (前提是他们已安装 MCP 服务器二进制文件)。

### 模板文件

[`templates/`](../templates/) 目录包含每个平台的初始配置。将适当的模板复制到工程的根文件夹，更新路径，然后将其提交到版本控制。

| 平台 | 模板 | 工程位置 |
|----------|----------|-----------------|
| GitHub Copilot | `templates/vscode-mcp.json` | `.vscode/mcp.json` |
| Amp | `templates/amp-settings.json` | `.amp/settings.json` |
| OpenAI Codex | `templates/codex-mcp.json` | 工程根目录中的 `.codex/config.json` |

> **Claude Code** 使用带有范围选择 (按工程、按用户或全局) 的 `claude plugin install` 而不是工程配置文件。请参阅[仅添加技能](#adding-skills-only)。

### 示例: GitHub Copilot

```bash
mkdir -p .vscode
cp /path/to/matlab-agentic-toolkit/templates/vscode-mcp.json .vscode/mcp.json
```

然后编辑 `.vscode/mcp.json`，将占位符路径替换为您实际的 MCP 服务器二进制文件和 MATLAB 根路径。

> **注意**: 按工程的配置包含指向 MCP 服务器二进制文件和 MATLAB 根的绝对路径，这些路径在不同计算机上会有所不同。如果您的团队使用不同的 OS 平台或安装位置，请考虑在工程 README 中记录预期路径。

---

## 故障排除

| 问题 | 可能原因 | 修复方法 |
|---------|-------------|-----|
| 设置无法找到 MATLAB | 非标准安装位置 | 在提示时提供路径 |
| MCP 服务器下载失败 | 网络/代理/防火墙 | 从 [GitHub releases](https://github.com/matlab/matlab-mcp-core-server/releases) 手动下载，放置在 `~/.matlab/agentic-toolkits/bin/` 中，重新运行设置 |
| macOS 阻止 MCP 服务器二进制文件 | Gatekeeper 隔离 | 设置会自动处理此问题。如果仍被阻止 (MDM)，请转到 "系统设置" > "隐私与安全性" > "仍要允许" |
| 智能体未列出 MATLAB 技能 | 插件未安装或技能未链接 | 重新运行设置; 对于 Claude Code，请尝试 `claude plugin install matlab-core@matlab-agentic-toolkit` |
| MCP 工具无法连接 | MCP 服务器二进制文件缺失或配置中路径错误 | 重新运行设置以重新生成配置。验证二进制文件是否存在: `~/.matlab/agentic-toolkits/bin/matlab-mcp-server --version` |
| `evaluate_matlab_code` 返回错误 | `--matlab-root` 路径错误、许可证问题或 MATLAB 启动失败 | 验证 MATLAB 能否启动: `<matlab-root>/bin/matlab -nodesktop -r "disp('ok'),quit"`。检查许可证状态。重新运行设置以更正 MATLAB 根路径 |
| Codex 工具调用超时 | 默认工具超时对于 MATLAB 太短 | 在 `~/.codex/config.toml` 的 `[mcp_servers.matlab]` 中添加 `tool_timeout_sec = 600` (或更高) |
| Simulink 在 Windows 上的 Codex 中失败 | 缺少 `WINDIR` 环境变量 | 在 `~/.codex/config.toml` 的 `[mcp_servers.matlab]` 中添加 `env_vars = ['WINDIR']` |
| 技能未自动加载 | 安装的技能过多 | 请参阅下面的[技能未自动加载](#skills-not-auto-loading) |

---

<a id="skills-not-auto-loading"></a>
### 技能未自动加载

智能体的上下文有限。当您安装多个技能组时，某些技能可能会被忽略或从上下文中修剪，并且您的智能体可能无法自动触发适合给定任务的正确技能。

#### 推荐的解决方案

1. 仅安装您需要的技能组: 这是推荐的解决方案。使用基于 MATLAB 的安装程序 (`setupAgenticToolkit("install")`) 选择与您的工作相关的特定技能组。安装的技能越少，意味着智能体可以更可靠地识别并触发正确的技能。

2. 按名称手动触发技能: 如果您知道需要哪个技能，请直接触发它。
   - 在 Claude Code 中，使用斜杠命令 (例如 `/matlab-write-tests`)。
   - 在其他智能体中，明确请求: "使用 matlab-write-tests 技能来..."。

3. 移除您不使用的技能组: 如果您通过基于智能体的设置安装了所有技能组，请移除您不需要的技能组。
   - Claude Code: `claude plugin remove <group-name>@matlab-agentic-toolkit`。
   - Copilot、Codex、Gemini CLI: 从 `~/.agents/skills/` 移除相应的符号链接。
   - Amp: 从 `~/.config/amp/settings.json` 中的 `amp.skills.path` 中移除该组路径。

我们正在积极探索更稳健的解决方案，以改进安装大量技能时的技能发现和自动加载。

---

## 支持和贡献
MathWorks 鼓励您使用此存储库并提供反馈。此存储库不启用拉取请求。要请求技术支持或提交增强请求，请[创建 GitHub issue](https://github.com/matlab/matlab-agentic-toolkit/issues) 或[联系技术支持](https://www.mathworks.com/support/contact_us.html)。

----

Copyright 2026 The MathWorks, Inc.

----
