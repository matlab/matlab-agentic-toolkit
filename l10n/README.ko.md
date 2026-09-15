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
  <a href="README.zh-cn.md">简体中文</a>
</p>

[![Latest Release](https://img.shields.io/github/v/release/matlab/matlab-agentic-toolkit?cacheSeconds=1800)](https://github.com/matlab/matlab-agentic-toolkit/releases/latest)
[![Release Date](https://img.shields.io/github/release-date/matlab/matlab-agentic-toolkit?cacheSeconds=1800)](https://github.com/matlab/matlab-agentic-toolkit/releases/latest)

MATLAB&reg; Agentic Toolkit은 AI 에이전트가 MATLAB 및 해당 툴박스와 효율적으로 작업하는 데 필요한 지식과 컨텍스트를 제공함으로써 MATLAB을 AI 에이전트와 함께 사용할 수 있도록 지원합니다. 이 툴킷을 사용하여 신뢰할 수 있는 MATLAB 기능을 에이전트에 제공하십시오. 이 툴킷은 AI 에이전트가 툴박스 함수 관련 할루시네이션을 일으키거나, 새로운 기능을 놓치거나, 숙련된 MATLAB 사용자라면 건너뛸 불필요한 단계에 시간을 낭비하는 일을 방지할 수 있습니다.

이 툴킷으로 다음과 같은 작업을 수행할 수 있습니다.

- AI 에이전트를 MATLAB에 연결합니다. 이 툴킷은 [MATLAB MCP Server](https://github.com/matlab/matlab-mcp-server)를 자동으로 설치하여 AI 에이전트를 MATLAB에 연결합니다. 그러면 에이전트를 사용해 관용적인 코드를 작성하고, 테스트를 생성 및 실행하며, 오류를 진단하고, 앱을 작성하는 등의 작업을 수행할 수 있습니다.

- 스킬(Skill)이라고 하는 엄선된 전문 지식을 에이전트에 제공합니다. 이러한 스킬은 에이전트에 MATLAB 워크플로, 규칙(conventions) 및 모범 사례(best practices)에 대한 지식을 제공하는 동시에 토큰 사용량을 최소화합니다.

> [!Note]
> AI 에이전트를 Simulink&reg;에서만 사용하려면 [Simulink Agentic Toolkit](https://github.com/matlab/simulink-agentic-toolkit)을 설치하십시오. 두 툴킷을 모두 설치하려면 [Agentic Toolkit 인스톨러](#matlab-agentic-toolkit-설치)를 사용하십시오.


## 요구 사항

* MATLAB R2021a 이상
* MCP 서버와 스킬을 지원하는 AI 코딩 에이전트. 지원되는 에이전트는 자동으로 구성됩니다. 지원되지 않는 에이전트의 경우에는 해당 문서를 참조하여 MCP 서버를 수동으로 구성하고 스킬을 설치하십시오. 지원되는 에이전트에는 다음이 포함됩니다.
    - Claude Code
    - GitHub&reg; Copilot
    - OpenAI&reg; Codex
    - Gemini&trade; CLI
    - Amp

---
## MATLAB Agentic Toolkit 시작하기

다음 단계에서는 MATLAB Agentic Toolkit을 사용하여 MATLAB MCP Server를 설치하고 에이전트에 스킬을 추가하는 방법을 보여줍니다.

> 참고: 로컬 파일에서의 설치, 오프라인 환경에서의 설치, 이 툴킷의 구성 옵션, 플랫폼별 참고 사항, 검증 절차, 문제 해결 및 인스톨러를 사용하지 않는 수동 설정에 대한 지침은 [Configuration and Troubleshooting](../Configuration_and_Troubleshooting.md)을 참조하십시오. MCP 서버가 이미 설치되어 있고 스킬만 추가해야 하는 경우 [Adding Skills Only](../Configuration_and_Troubleshooting.md#adding-skills-only)를 참조하십시오.

### MATLAB Agentic Toolkit 설치

다음 단계에 따라 MATLAB Agentic Toolkit을 설치하십시오.

1. 인스톨러를 다운로드하려면 [agenticToolkitInstaller.mltbx](https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx)를 클릭하십시오.
2. 다운로드한 파일을 MATLAB에서 열어 인스톨러 애드온을 설치하십시오.
3. MATLAB에서 다음 명령을 실행하십시오.

```matlab
setupAgenticToolkit("install")
```

4. 업무와 관련된 스킬 그룹만 설치하십시오. 이렇게 하면 에이전트가 적절한 스킬을 보다 안정적으로 트리거할 수 있습니다. 나중에 다른 스킬 그룹을 추가하려면, 인스톨러를 다시 실행하십시오.
5. 기본적으로 에이전트를 호출하면 새 MATLAB 세션이 생성됩니다. 에이전트를 기존 MATLAB 세션에 연결하려면 MATLAB 명령 창에서 다음 명령을 실행하십시오.

```
shareMATLABSession()
```

여러 MATLAB 세션을 실행 중인 경우 에이전트는 이 명령을 가장 최근에 실행한 MATLAB 세션에 연결됩니다.

또는 이 명령을 MATLAB [시작 스크립트](https://www.mathworks.com/help/matlab/ref/startup.html)에 추가할 수도 있습니다.


### 검증
에이전트에 다음과 같이 질문하십시오.

```
What version of MATLAB is running? List the installed toolboxes.
```

### MCP 툴을 사용한 MATLAB 코드 실행 및 테스트
MATLAB Agentic Toolkit을 설치한 후에는 에이전트가 MATLAB MCP Server에서 제공하는 다음 툴을 사용할 수 있습니다.

| 에이전트에 요청할 수 있는 작업 | 에이전트가 사용하는 툴 |
|------|------------------------|
| MATLAB 코드를 실행하고 명령 창 출력을 반환 | `evaluate_matlab_code` |
| MATLAB 프로그램 실행 | `run_matlab_file` |
| `runtests`를 통해 테스트를 실행하고 구조화된 결과를 반환 | `run_matlab_test_file`|
| 코드 분석기를 사용한 정적 분석 | `check_matlab_code` |
| 설치된 MATLAB 버전 및 툴박스 나열 | `detect_matlab_toolboxes` |

서버는 `matlab_coding_guidelines`(코딩 표준)와 `plain_text_live_code_guidelines`(라이브 스크립트 형식 규칙)의 두 가지 MCP 리소스도 제공합니다. 이러한 리소스는 에이전트가 필요에 따라 읽을 수 있는 참조 정보를 제공합니다.

### 에이전트 스킬을 사용하여 MATLAB 워크플로 실행
MATLAB Agentic Toolkit을 설치한 후에는 에이전트가 MathWorks&reg;가 엄선하여 제공하는 스킬을 사용할 수 있습니다. 최상의 결과를 얻으려면 업무와 관련된 스킬 그룹만 설치하십시오. 로드된 스킬이 적을수록 에이전트가 적절한 스킬을 보다 안정적으로 트리거할 수 있습니다. 특정 스킬이 반드시 로드되도록 하려면, 해당 스킬의 이름을 사용해 직접 트리거할 수도 있습니다(예: Claude Code에서 `/matlab-write-tests`). 모든 스킬에 대한 자세한 내용은 [스킬 카탈로그](skills-catalog/README.ko.md)를 참조하십시오. 스킬 그룹에는 다음이 포함됩니다.

<!-- BEGIN SKILLS -->
#### MATLAB 스킬

| 스킬 그룹 | 설명 |
|-------------|-------------|
| [**MATLAB 코어**](skills-catalog/README.ko.md#matlab-코어-matlab-core) | MATLAB 코드를 생성, 디버그, 테스트, 검토하고 MATLAB 설치를 관리 |
| [**MATLAB 앱 작성**](skills-catalog/README.ko.md#matlab-앱-작성-matlab-app-building) | UI 컴포넌트, 레이아웃, 콜백, 웹 통합을 사용하여 프로그래밍 방식으로 MATLAB 앱 작성 |
| [**MATLAB 데이터 가져오기 및 분석**](skills-catalog/README.ko.md#matlab-데이터-가져오기-및-분석-matlab-data-import-and-analysis) | 테이블, 타임테이블, 필터링, 집계, 시계열 연산을 사용하여 MATLAB에서 데이터 가져오기, 내보내기 및 분석 |
| [**MATLAB 환경 및 설정**](skills-catalog/README.ko.md#matlab-환경-및-설정-matlab-environment-and-settings) | MATLAB 릴리스 간 설정 차이를 비교하고, 시작 스크립트(Startup Script)가 올바른 설정 경로를 사용하도록 마이그레이션 |
| [**MATLAB 외부 언어 인터페이스**](skills-catalog/README.ko.md#matlab-외부-언어-인터페이스-matlab-external-language-interfaces) | MATLAB에서 Python&reg; 라이브러리를 호출하고, MEX 파일을 interleaved complex API(실수부/허수부 결합형 복소수 API)로 업그레이드 |
| [**MATLAB 프로그래밍**](skills-catalog/README.ko.md#matlab-프로그래밍-matlab-programming) | 입력값 유효성을 검사하는 견고한 MATLAB 함수 작성 |
| [**MATLAB 소프트웨어 개발**](skills-catalog/README.ko.md#matlab-소프트웨어-개발-matlab-software-development) | 레거시 코드 현대화, 성능 및 메모리 최적화, 툴박스 문서화 및 생성, 프로젝트 생성, 빌드 계획 개발 |

#### 툴박스 스킬

| 스킬 그룹 | 지원 제품 |
|-------------|--------------------|
| [**항공우주**](skills-catalog/README.ko.md#항공우주-aerospace) | MATLAB, Aerospace Toolbox&trade; |
| [**AI 및 통계학**](skills-catalog/README.ko.md#ai-및-통계학-ai-and-statistics) | MATLAB, Simulink, Curve Fitting Toolbox&trade;, Deep Learning Toolbox&trade;, Embedded Coder&trade;, Fixed-Point Designer&trade;, MATLAB Coder&trade;, MATLAB Compiler SDK&trade;, MATLAB Report Generator&trade;, Optimization Toolbox&trade;, Parallel Computing Toolbox&trade;, Statistics and Machine Learning Toolbox&trade;, Deep Learning Toolbox Converter for ONNX Model Format&trade;, Deep Learning Toolbox Converter for PyTorch Models&trade;, Deep Learning Toolbox Converter for TensorFlow Models&trade; |
| [**자동차**](skills-catalog/README.ko.md#자동차-automotive) | MATLAB, Simulink, Automated Driving Toolbox&trade;, Computer Vision Toolbox&trade;, RoadRunner, RoadRunner Scenario, RoadRunner Scene Builder, Sensor Fusion and Tracking Toolbox&trade;, Automated Driving Toolbox Interface for Eclipse SUMO Traffic Simulator&trade;, Scenario Builder for Automated Driving Toolbox&trade; |
| [**클라우드 솔루션**](skills-catalog/README.ko.md#클라우드-솔루션-cloud-solutions) | MATLAB, MATLAB Drive&trade; |
| [**코드 생성**](skills-catalog/README.ko.md#코드-생성-code-generation) | MATLAB, Embedded Coder, Fixed-Point Designer, GPU Coder&trade;, MATLAB Coder, MATLAB Test&trade;, Parallel Computing Toolbox, MATLAB Coder Support Package for PyTorch and LiteRT Models&trade; |
| [**계산 생물학**](skills-catalog/README.ko.md#계산-생물학-computational-biology) | MATLAB, SimBiology&trade;, Statistics and Machine Learning Toolbox |
| [**계산 금융**](skills-catalog/README.ko.md#계산-금융-computational-finance) | MATLAB, Datafeed Toolbox&trade;, Financial Instruments Toolbox&trade;, Financial Toolbox&trade;, Spreadsheet Link&trade; |
| [**제어 시스템**](skills-catalog/README.ko.md#제어-시스템-control-systems) | MATLAB, Control System Toolbox&trade;, Predictive Maintenance Toolbox&trade;, Signal Processing Toolbox&trade;, Statistics and Machine Learning Toolbox, System Identification Toolbox&trade; |
| [**영상 처리 및 컴퓨터 비전**](skills-catalog/README.ko.md#영상-처리-및-컴퓨터-비전-image-processing-and-computer-vision) | MATLAB, Computer Vision Toolbox, Deep Learning Toolbox, Image Processing Toolbox&trade;, Lidar Toolbox&trade;, Medical Imaging Toolbox&trade;, Optical Design and Simulation Library for Image Processing Toolbox&trade; |
| [**수학 및 최적화**](skills-catalog/README.ko.md#수학-및-최적화-math-and-optimization) | MATLAB, Optimization Toolbox, Partial Differential Equation Toolbox&trade;, Symbolic Math Toolbox&trade; |
| [**병렬 연산**](skills-catalog/README.ko.md#병렬-연산-parallel-computing) | MATLAB, Parallel Computing Toolbox, MATLAB Parallel Server&trade; |
| [**레이다**](skills-catalog/README.ko.md#레이다-radar) | MATLAB, Mapping Toolbox&trade;, Phased Array System Toolbox&trade;, Radar Toolbox&trade;, Sensor Fusion and Tracking Toolbox, Signal Processing Toolbox |
| [**리포팅 및 데이터베이스 액세스**](skills-catalog/README.ko.md#리포팅-및-데이터베이스-액세스-reporting-and-database-access) | MATLAB, Database Toolbox&trade;, MATLAB Report Generator, Parallel Computing Toolbox, Simulink Report Generator&trade; |
| [**RF 및 혼성 신호**](skills-catalog/README.ko.md#rf-및-혼성-신호-rf-and-mixed-signal) | MATLAB, Simulink, Antenna Toolbox&trade;, Mixed-Signal Blockset&trade;, RF Blockset&trade;, RF PCB Toolbox&trade;, RF Toolbox&trade;, SerDes Toolbox&trade;, Signal Integrity Toolbox, Signal Processing Toolbox, Statistics and Machine Learning Toolbox |
| [**로보틱스 및 자율 시스템**](skills-catalog/README.ko.md#로보틱스-및-자율-시스템-robotics-and-autonomous-systems) | MATLAB, Navigation Toolbox&trade;, UAV Toolbox&trade;, Robotics System Toolbox&trade; |
| [**신호 처리**](skills-catalog/README.ko.md#신호-처리-signal-processing) | MATLAB, Simulink, Audio Toolbox&trade;, DSP HDL Toolbox&trade;, DSP System Toolbox&trade;, Fixed-Point Designer, HDL Coder&trade;, Signal Processing Toolbox, Wavelet Toolbox&trade; |
| [**테스트 및 계측**](skills-catalog/README.ko.md#테스트-및-계측-test-and-measurement) | MATLAB, Data Acquisition Toolbox&trade;, Image Acquisition Toolbox&trade;, Image Processing Toolbox, Industrial Communication Toolbox&trade;, Vehicle Network Toolbox&trade;, MATLAB Support Package for Arduino Hardware&trade; |
| [**무선 통신**](skills-catalog/README.ko.md#무선-통신-wireless-communications) | MATLAB, 5G Toolbox&trade;, Bluetooth&reg; Toolbox&trade;, Communications Toolbox&trade;, Satellite Communications Toolbox&trade;, Wireless Network Toolbox&trade;, Wireless Testbench&trade;, WLAN Toolbox&trade;, Wireless Testbench Support Package for NI USRP Radios&trade; |
<!-- END SKILLS -->
---
## MATLAB Agentic Toolkit 업데이트하기

툴킷을 업데이트하려면 [agenticToolkitInstaller.mltbx](https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx)를 클릭하여 최신 인스톨러 애드온을 다운로드하십시오. 다운로드한 파일을 MATLAB에서 열고 MATLAB에서 다음 명령을 실행하십시오.

```matlab
setupAgenticToolkit("update")
```

이렇게 하면 MATLAB 및 Simulink Agentic Toolkit의 스킬과 구성 설정, MCP 서버 바이너리가 업데이트됩니다.

---
## 보안 고려 사항
MATLAB Agentic Toolkit 및 MATLAB MCP Server를 사용할 때는 모든 툴 호출을 실행하기 전에 철저히 검토하고 유효성을 검사해야 합니다. 중요한 작업에는 항상 사람이 개입하도록 하고, 호출이 예상대로 정확히 수행될 것이라고 확신하는 경우에만 진행하십시오. 자세한 내용은 [User Interaction Model (MCP)](https://modelcontextprotocol.io/specification/latest/server/tools#user-interaction-model) 및 [Security Considerations (MCP)](https://modelcontextprotocol.io/specification/latest/server/tools#security-considerations)를 참조하십시오.

---
## 데이터 수집

MATLAB MCP Server는 기본적으로 익명화된 사용 데이터를 수집합니다. 전체 세부 정보는 MCP 서버 문서의 [데이터 수집](https://github.com/matlab/matlab-mcp-server/blob/main/l10n/README.ko.md#데이터-수집)을 참조하십시오. 데이터 수집을 거부하려면 [Disable Data Collection](../Configuration_and_Troubleshooting.md#disable-data-collection)을 참조하십시오.

---
## 라이선스 및 사용
라이선스는 이 GitHub 리포지토리의 [LICENSE.md](../LICENSE.md) 파일에서 확인할 수 있습니다.

MathWorks 소프트웨어 라이선스 계약에 따라 MATLAB과 함께 사용하는 경우에만 MCP 서버 사용이 허용되며, 여러 사용자가 MCP 서버를 공유해서는 안 됩니다. 공유 또는 중앙 집중식 서버 사용을 지원해야 하는 경우 MathWorks에 문의하십시오.

---
## 지원 및 기여
MathWorks는 이 리포지토리를 사용하고 피드백을 제공해 주시기를 권장합니다. 이 리포지토리에서는 풀 리퀘스트(Pull Request)를 사용할 수 없습니다. 기술 지원을 요청하거나 개선 사항을 제출하려면 [GitHub 이슈를 생성](https://github.com/matlab/matlab-agentic-toolkit/issues)하거나 [MathWorks 기술 지원팀](https://www.mathworks.com/support/contact_us.html)에 문의하십시오.


----

Copyright 2026 The MathWorks, Inc.

----
