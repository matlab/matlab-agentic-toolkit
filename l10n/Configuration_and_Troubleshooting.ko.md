<!--
Source English Markdown:
- File: ./Configuration_and_Troubleshooting.md
- Branch: main
- Commit: 645cf259dedf8b012f89fdb7006ad7c1afa33e3e
-->

# 구성 및 문제 해결

<p align="center">
  <a href="../Configuration_and_Troubleshooting.md">English</a> •
  <a href="Configuration_and_Troubleshooting.es.md">Español</a> •
  <a href="Configuration_and_Troubleshooting.ja.md">日本語</a> •
  한국어 •
  <a href="Configuration_and_Troubleshooting.zh-cn.md">简体中文</a>
</p>

이 페이지에서는 MATLAB&reg; Agentic Toolkit을 구성하는 방법을 설명합니다. MATLAB Agentic Toolkit에 대한 개요는 [README](README.ko.md)를 참조하십시오.

## 요구 사항

- MATLAB R2021a 이상
- MCP 서버 및 스킬을 지원하는 AI 코딩 에이전트. 지원되는 에이전트는 자동으로 구성됩니다. 지원되지 않는 에이전트의 경우에는 해당 에이전트 문서를 참조하여 MCP 서버를 수동으로 구성하고 스킬을 설치하십시오. 지원되는 에이전트에는 다음이 포함됩니다.
  - Claude Code
  - GitHub&reg; Copilot
  - OpenAI&reg; Codex
  - Gemini&trade; CLI
  - Amp

---

## 로컬 파일에서 설치(오프라인 컴퓨터)

오프라인 또는 에어갭(Air Gap) 환경에서 MATLAB Agentic Toolkit을 설치하려면, 먼저 인터넷에 액세스 가능한 컴퓨터에서 다음 아티팩트를 다운로드하여 대상 머신이나 공유 위치로 전송하십시오.

| 아티팩트 | 다운로드 위치 |
|----------|----------------|
| MCP Server 바이너리 | [MATLAB MCP Server latest release](https://github.com/matlab/matlab-mcp-server/releases/latest) — 사용 중인 플랫폼에 맞는 바이너리를 다운로드하십시오 (예: `matlab-mcp-server-macos-arm64`, `matlab-mcp-server-windows-x64.exe`). |
| MCP Server Toolbox | [MATLAB MCP Server latest release](https://github.com/matlab/matlab-mcp-server/releases/latest) — `MATLABMCPServerToolbox.mltbx`를 다운로드하십시오. |
| Agentic Toolkit 인스톨러 | [Simulink Agentic Toolkit latest release](https://github.com/matlab/simulink-agentic-toolkit/releases/latest) — `agenticToolkitInstaller.mltbx`를 다운로드하십시오. |
| MATLAB Agentic Toolkit | [GitHub](https://github.com/matlab/matlab-agentic-toolkit)에서 복제하거나 다운로드하십시오. |
| Simulink Agentic Toolkit | [GitHub](https://github.com/matlab/simulink-agentic-toolkit)에서 복제하거나 다운로드하십시오. Simulink Agentic Toolkit을 설치할 때만 필요합니다.|

이러한 아티팩트를 다운로드한 후, MATLAB에서 `agenticToolkitInstaller.mltbx`를 열어 인스톨러 애드온을 설치하십시오.
MATLAB에서 명령 창에 다음 이름-값 인수를 지정하여 `setupAgenticToolkit` 명령을 실행하십시오.

| 인수 | 값 |
|----------|-----------------|
| `MCPServerLocation` | MCP Server 바이너리 다운로드 경로 |
| `MCPToolboxLocation` | MATLAB 툴박스(`.mltbx`) 다운로드 경로 |
| `MATLABAgenticToolkitLocation` | MATLAB Agentic Toolkit 리포지토리 복제본 경로 |
| `SimulinkAgenticToolkitLocation` | Simulink Agentic Toolkit 리포지토리 복제본 경로 |

인스톨러는 로컬로 제공되지 않은 아티팩트를 다운로드합니다. 인터넷 액세스를 차단하고 필요한 아티팩트를 사용할 수 없는 경우 오류를 보고하도록 하려면 `Offline=true`로 설정하십시오. 예를 들어, 로컬 파일에서 MATLAB Agentic Toolkit을 설치하려면 다음 명령을 사용하십시오.

```matlab
setupAgenticToolkit("install", Offline=true,  ...
    MCPServerLocation="/shared/agentic-toolkits/bin/matlab-mcp-server-linux-x64", ...
    MCPToolboxLocation="/shared/agentic-toolkits/toolboxes/MATLABMCPServerToolbox.mltbx", ...
    MATLABAgenticToolkitLocation="/shared/agentic-toolkits/matlab-agentic-toolkit")
```

---

## 에이전트를 사용하여 MATLAB 설치

MATLAB이 설치되어 있지 않은 경우, 다음 단계에 따라 AI 에이전트를 사용하여 MATLAB을 설치할 수 있습니다.
1) [스킬만 추가하기](#adding-skills-only) 섹션의 단계에 따라 MATLAB Agentic Toolkit 스킬을 설치합니다.
2) `matlab-install-products` 스킬을 사용하여 MATLAB을 설치하도록 에이전트에 요청합니다.

MATLAB을 설치한 후에는 [Agentic Toolkit 인스톨러](README.ko.md#matlab-agentic-toolkit-설치)의 지침을 따라 MATLAB MCP Server를 자동으로 설치하거나, MATLAB MCP Server를 수동으로 설치 및 구성하여 MATLAB Agentic Toolkit 설정을 완료할 수 있습니다.

---

## MCP 서버 설치 및 구성

자동 설정 기능을 사용하지 않고 MCP 서버를 수동으로 설치하고 구성하려면, [MATLAB MCP Server](https://github.com/matlab/matlab-mcp-core-server) GitHub 리포지토리의 지침을 참조하십시오. MCP 서버를 설치한 후에는, 에이전트의 MCP 구성이 해당 바이너리를 사용하도록 설정하십시오. 구성 파일 위치는 다음 표를 참조하거나, 에이전트의 문서를 참조하십시오.

| 플랫폼 | MCP 구성 | 플랫폼별 참고 사항 |
|----------|------------------|-------------------|
| Claude Code | `~/.claude.json` | 구성하려면 `claude mcp add`를 사용하십시오. |
| GitHub Copilot | VS Code 사용자 프로파일 `mcp.json` | 설정이 완료된 후 VS Code를 다시 로드하십시오. |
| OpenAI Codex | `~/.codex/config.toml` | 설정을 완료한 후에는, `~/.codex/config.toml`의 `[mcp_servers.matlab]` 섹션에서 두 가지 설정을 조정할 수 있습니다. 1) 테스트 스위트나 시뮬레이션과 같이 실행 시간이 긴 MATLAB 작업에 대한 툴 제한 시간을 늘리려면 `tool_timeout_sec = 600`으로 설정하십시오. 작업 실행 시간이 매우 긴 경우에는 이 값을 더 늘리십시오. 2) Codex는 기본적으로 MCP 서버 하위 프로세스에서 환경 변수를 제거하므로, Simulink&reg;가 Windows&reg;에서 작동하도록 하려면 `env_vars = ['WINDIR']`을 설정하십시오. |
| Gemini CLI | `~/.gemini/settings.json` | 설정 후 새 Gemini 세션을 시작하십시오. |
| Amp | `~/.config/amp/settings.json` | `amp.mcpPermissions` 규칙에 의해 MCP 서버가 차단되는 경우, MATLAB 서버에 대한 허용 규칙을 추가하십시오. |

---

## 데이터 수집 비활성화

MATLAB MCP Server는 서버 사용에 대한 완전히 익명화된 정보를 수집하여 MathWorks&reg;로 전송합니다. 이 데이터 수집은 MathWorks의 제품 개선에 도움이 되며 기본적으로 활성화되어 있습니다. 데이터 수집을 거부하려면, MATLAB에서 다음 명령을 실행하여 `DisableTelemetry` 옵션을 `true`로 설정하여 툴킷을 구성하십시오.

```matlab
setupAgenticToolkit("configure", DisableTelemetry=true)
```

이 명령은 구성된 모든 에이전트를 데이터 수집 대상에서 제외합니다. 이 설정은 `setupAgenticToolkit("update")`를 실행하여 툴킷을 새 버전으로 업데이트한 후에도 유지됩니다. `setupAgenticToolkit("configure")`를 실행하여 에이전트에 대한 툴킷을 다시 구성하는 경우에는, 데이터 수집을 비활성 상태로 유지하려면 `DisableTelemetry=true`를 다시 포함하십시오.

---

<a id="adding-skills-only"></a>
## 스킬만 추가하기

이미 MATLAB MCP Server가 있다면 스킬만 추가하면 됩니다. 스킬은 `skills-catalog/` 아래의 폴더로 구성되어 있으며, 이를 스킬 그룹이라고 합니다. `matlab-core` 스킬 그룹은 반드시 설치해야 합니다. 특정 분야에 대한 전문성을 제공하려면 다른 스킬 그룹을 별도로 설치할 수 있습니다. 에이전트가 스킬을 안정적으로 트리거할 수 있도록 필요한 스킬만 설치하십시오. 워크플로에서 특정 스킬이 로드되도록 하려면, 해당 스킬의 이름을 사용하여 직접 트리거할 수도 있습니다.

스킬 그룹 및 스킬에 대한 자세한 내용은 [`skills-catalog/` README](skills-catalog/README.ko.md)를 참조하십시오.

### Claude Code

각 스킬 그룹은 Claude Code 플러그인으로 제공됩니다. 스킬 그룹을 추가하려면, 먼저 마켓플레이스를 추가한 다음 `matlab-core` 스킬 그룹을 설치하십시오.

```bash
claude plugin marketplace add "https://github.com/matlab/matlab-agentic-toolkit"
claude plugin install matlab-core@matlab-agentic-toolkit
```

`matlab-core` 스킬 그룹을 설치한 후에는, 스킬 그룹의 디렉터리 이름을 사용하여 동일한 패턴으로 원하는 스킬 그룹을 설치하십시오.

```bash
claude plugin install <group-name>@matlab-agentic-toolkit
```

예를 들어, 신호 처리 및 무선 통신 스킬을 추가하려면 다음과 같이 하십시오.

```bash
claude plugin install signal-processing@matlab-agentic-toolkit
claude plugin install wireless-communications@matlab-agentic-toolkit
```

범위를 선택하라는 프롬프트가 표시되면 원하는 범위(프로젝트별, 사용자별 또는 전역)를 선택하십시오. 기존 MCP 구성은 수정되지 않습니다.


### GitHub Copilot, OpenAI Codex, Gemini CLI

대부분의 다른 AI 에이전트는 `~/.agents/skills/`에서 스킬을 검색합니다. 에이전트에 스킬을 추가하려면, `~/.agents/skills/` 폴더에서 개별 스킬 그룹을 가리키는 심볼릭 링크를 설정해야 합니다. 먼저, 툴킷을 복제하십시오.

```bash
git clone https://github.com/matlab/matlab-agentic-toolkit.git
```

툴킷을 복제한 후, 원하는 각 그룹에 대해 심볼릭 링크를 만드십시오. `/path/to/matlab-agentic-toolkit`을 툴킷 복제본의 실제 경로로 바꾸고, 필요한 스킬 그룹을 나열하십시오. 예를 들어, `matlab-core`와 `signal-processing`을 설치하려면 다음 명령을 사용하십시오.

```bash
mkdir -p ~/.agents/skills
for group in matlab-core signal-processing; do
  for skill in /path/to/matlab-agentic-toolkit/skills-catalog/$group/*/; do
    ln -s "$skill" ~/.agents/skills/$(basename "$skill")
  done
done
```

또는 Gemini의 경우, 툴킷을 Gemini CLI 확장 기능으로 설치하여 스킬을 추가할 수 있습니다.
  ```bash
 gemini extensions install https://github.com/matlab/matlab-agentic-toolkit
  ```

### Amp

Amp는 `~/.config/amp/settings.json`에 나열된 경로에서 스킬을 읽어 옵니다. 먼저, 툴킷을 복제하십시오.

```bash
git clone https://github.com/matlab/matlab-agentic-toolkit.git
```

툴킷을 복제한 후, 원하는 각 그룹에 대해 `skills-catalog/<group>` 경로 항목을 추가하십시오.

```json
{
  "amp.skills.path": [
    "/path/to/matlab-agentic-toolkit/skills-catalog/matlab-core",
    "/path/to/matlab-agentic-toolkit/skills-catalog/signal-processing"
  ]
}
```

---

## 검증

### 스킬이 로드되었는지 확인하기

에이전트의 UI에 로드된 스킬 또는 플러그인이 표시되는 경우(예: Claude Code의 `/skills` 명령), MATLAB Agentic Toolkit 스킬이 나열되어 있는지 확인하십시오.

### 직접 사용해 보기

에이전트에게 다음과 같이 질문하십시오.

```
What version of MATLAB is running? List the installed toolboxes.
```

에이전트는 MCP를 사용하여 `detect_matlab_toolboxes`를 호출하고 MATLAB 버전과 사용 가능한 툴박스를 보고합니다.

### 추가 예시

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

## 프로젝트별 구성

최상위 [README](README.ko.md)에 설명된 자동 설정 기능을 사용하여 MATLAB Agentic Toolkit을 설치하면, 툴킷이 전역적으로 구성됩니다. 어떤 프로젝트를 열든 관계없이 모든 세션에서 MATLAB 툴과 스킬을 사용할 수 있습니다.

MCP 서버를 프로젝트 수준에서 구성할 수도 있습니다. 이렇게 하면 툴과 스킬의 적용 범위를 해당 기능이 필요한 프로젝트로만 제한할 수 있습니다. 해당 구성을 버전 컨트롤에 커밋하면 팀 협업에도 도움이 됩니다. 리포지토리를 복제하는 사용자는 MCP Server 바이너리가 설치되어 있는 경우 MATLAB 연결 구성을 자동으로 사용할 수 있게 됩니다.

### 템플릿 파일

[`templates/`](../templates/) 디렉터리에는 각 플랫폼에 대한 초기 구성이 포함되어 있습니다. 적절한 템플릿을 프로젝트의 루트 폴더에 복사한 다음 경로를 업데이트하고 버전 컨트롤에 커밋하십시오.

| 플랫폼 | 템플릿 | 프로젝트 위치 |
|----------|----------|-----------------|
| GitHub Copilot | `templates/vscode-mcp.json` | `.vscode/mcp.json` |
| Amp | `templates/amp-settings.json` | `.amp/settings.json` |
| OpenAI Codex | `templates/codex-mcp.json` | 프로젝트 루트의 `.codex/config.json` |

> **Claude Code**는 프로젝트 구성 파일 대신 `claude plugin install`을 사용하며 이때 범위(프로젝트별, 사용자별 또는 전역)를 선택합니다. [스킬만 추가하기](#adding-skills-only)를 참조하십시오.

### 예시: GitHub Copilot

```bash
mkdir -p .vscode
cp /path/to/matlab-agentic-toolkit/templates/vscode-mcp.json .vscode/mcp.json
```

그런 다음 `.vscode/mcp.json`을 편집하여 자리 표시자 경로를 실제 MCP Server 바이너리 경로와 MATLAB 루트 경로로 바꾸십시오.

> **참고:** 프로젝트별 구성에는 MCP Server 바이너리와 MATLAB 루트에 대한 절대 경로가 포함되며, 이 경로는 머신마다 다를 수 있습니다. 팀이 서로 다른 OS 플랫폼이나 설치 위치를 사용하는 경우에는 해당 경로를 프로젝트 README에 문서화하는 것을 고려하십시오.

---

## 문제 해결

| 문제 | 가능한 원인 | 해결 방법 |
|---------|-------------|-----|
| 설정 절차에서 MATLAB을 찾지 못함 | 표준이 아닌 위치에 설치되어 있음 | 프롬프트가 표시되면 경로를 제공하십시오. |
| MCP 서버 다운로드 실패 | 네트워크/프록시/방화벽 | [GitHub releases](https://github.com/matlab/matlab-mcp-core-server/releases)에서 수동으로 다운로드한 다음 `~/.matlab/agentic-toolkits/bin/`에 배치하고 설정 절차를 다시 실행하십시오. |
| macOS가 MCP Server 바이너리를 차단함 | Gatekeeper 격리 | 설정 절차에서 자동으로 처리합니다. 계속 차단되는 경우(MDM), Settings > Privacy & Security > Allow Anyway로 이동하십시오. |
| 에이전트가 MATLAB 스킬을 나열하지 않음 | 플러그인이 설치되지 않았거나 스킬이 연결되지 않음 | 설정 절차를 다시 실행하십시오. Claude Code의 경우 `claude plugin install matlab-core@matlab-agentic-toolkit`을 시도하십시오. |
| MCP 툴이 연결되지 않음 | MCP Server 바이너리가 없거나 구성에 지정된 경로가 잘못됨 | 구성을 다시 생성하려면 설정 절차를 다시 실행하십시오. 바이너리가 존재하는지 확인하려면 `~/.matlab/agentic-toolkits/bin/matlab-mcp-server --version` 명령을 실행하십시오.|
| `evaluate_matlab_code`가 오류를 반환함 | 잘못된 `--matlab-root` 경로, 라이선스 문제 또는 MATLAB 시작 실패 | MATLAB이 시작되는지 확인하려면 `<matlab-root>/bin/matlab -nodesktop -r "disp('ok'),quit"` 명령을 실행하십시오. 라이선스 상태를 확인하십시오. MATLAB 루트 경로를 수정하려면 설정 절차를 다시 실행하십시오. |
| Codex 툴 호출이 시간 초과됨 | 툴의 기본 제한 시간이 MATLAB 작업에 비해 너무 짧음 | `~/.codex/config.toml`의 `[mcp_servers.matlab]`에 `tool_timeout_sec = 600`(또는 그 이상)을 추가하십시오. |
| Windows의 Codex에서 Simulink가 실패함 | `WINDIR` 환경 변수가 없음 | `~/.codex/config.toml`의 `[mcp_servers.matlab]`에 `env_vars = ['WINDIR']`을 추가하십시오. |
| 스킬이 자동 로드되지 않음 | 설치된 스킬이 너무 많음 | 아래의 [스킬이 자동 로드되지 않음](#skills-not-auto-loading) 섹션을 참조하십시오. |

---

<a id="skills-not-auto-loading"></a>
### 스킬이 자동 로드되지 않음

에이전트는 제한된 컨텍스트를 가집니다. 많은 스킬 그룹을 설치하면 일부 스킬이 간과되거나 컨텍스트에서 잘릴 수 있으며, 이로 인해 에이전트가 주어진 작업에 대해 올바른 스킬을 자동으로 트리거하지 못할 수 있습니다.

#### 권장 해결 방법

1. 필요한 스킬 그룹만 설치하기: 이것이 권장되는 해결 방법입니다. MATLAB 기반 인스톨러(`setupAgenticToolkit("install")`)를 사용하여 작업과 관련된 특정 스킬 그룹을 선택하십시오. 설치된 스킬이 적을수록 에이전트가 적절한 스킬을 더 안정적으로 식별하고 트리거할 수 있습니다.

2. 스킬 이름을 사용하여 직접 트리거하기: 필요한 스킬을 알고 있으면 해당 스킬을 직접 트리거하십시오.
   - Claude Code에서는 슬래시 명령을 사용하십시오(예: `/matlab-write-tests`).
   - 다른 에이전트에서는 명시적으로 요청하십시오: "Use the matlab-write-tests skill to...".

3. 사용하지 않는 스킬 그룹을 제거하기: 에이전트 기반 설정을 통해 모든 그룹을 설치한 경우, 필요하지 않은 그룹을 제거하십시오.
   - Claude Code: `claude plugin remove <group-name>@matlab-agentic-toolkit`
   - Copilot, Codex, Gemini CLI: `~/.agents/skills/`에서 해당 심볼릭 링크를 제거하십시오.
   - Amp: `~/.config/amp/settings.json`의 `amp.skills.path`에서 해당 그룹 경로를 제거하십시오.

많은 스킬이 설치된 환경에서 스킬 검색 및 자동 로드 기능을 개선하기 위해 보다 견고한 해결 방안을 적극적으로 모색하고 있습니다.

---

## 지원 및 기여
MathWorks는 이 리포지토리를 사용하고 피드백을 제공해 주시기를 권장합니다. 이 리포지토리에서는 풀 리퀘스트(Pull Request)를 사용할 수 없습니다. 기술 지원을 요청하거나 개선 요청을 제출하려면, [GitHub 이슈를 생성](https://github.com/matlab/matlab-agentic-toolkit/issues)하거나 [기술 지원팀에 문의](https://www.mathworks.com/support/contact_us.html)하십시오.

----

Copyright 2026 The MathWorks, Inc.

----
