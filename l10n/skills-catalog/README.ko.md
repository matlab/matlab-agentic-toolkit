<!--
Source English Markdown:
- File: ./skills-catalog/README.md
- Branch: main
- Commit: cd7a55815df574409a09d14d6333641cc86cff3e
-->

# 스킬 카탈로그

<p align="center">
  <a href="../../skills-catalog/README.md">English</a> •
  <a href="README.es.md">Español</a> •
  <a href="README.ja.md">日本語</a> •
  <a href="README.ko.md">한국어</a> •
  <a href="README.zh-cn.md">简体中文</a>
</p>

스킬(Skill) 카탈로그는 에이전트 스킬을 그룹별로 구성합니다. 각 그룹에는 하나 이상의 스킬 폴더가 포함되어 있으며, 각 폴더에는 `SKILL.md` 파일과 `manifest.yaml` 파일이 있습니다. `manifest.yaml` 파일에는 해당 스킬의 메타데이터가 포함되어 있습니다.

## 스킬

<!-- BEGIN SKILLS -->
### MATLAB 코어 ([`matlab-core`](../../skills-catalog/matlab-core/))

MATLAB&reg; 코드를 생성, 디버그, 테스트, 검토하고 MATLAB 설치를 관리

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-create-live-script` | 서식 있는 텍스트, LaTeX 수식, 인라인 그림이 포함된 일반 텍스트 MATLAB 라이브 스크립트를 생성합니다. |
| `matlab-debug-code` | MATLAB 오류 및 예기치 않은 동작을 진단합니다. |
| `matlab-install-products` | MATLAB Package Manager(mpm)를 사용하여 명령줄에서 MathWorks&reg; 제품을 설치합니다. |
| `matlab-list-products` | 지정된 MATLAB 설치 폴더에 설치된 모든 MATLAB 제품 및 지원 패키지를 표시합니다. |
| `matlab-read-documentation` | 사용 중인 MATLAB 릴리스에 해당하는 MathWorks 문서를 가져와 탐색하여 올바른 함수 구문, 완전한 워크플로 및 MATLAB과 Simulink&reg; 소프트웨어 사용 모범 사례를 확인합니다. |
| `matlab-review-code` | MATLAB 코드의 품질, 성능, 유지보수성, MathWorks 코딩 표준 준수 여부를 검토합니다. |
| `matlab-run-tests` | MATLAB 테스트 스위트를 실행하고, 코드 커버리지를 수집하고, CI/CD 파이프라인을 구성합니다. |
| `matlab-write-tests` | 클래스 기반 테스트 프레임워크를 사용하여 MATLAB 단위 테스트를 생성하고 구조화합니다. |

### MATLAB 앱 작성 ([`matlab-app-building`](../../skills-catalog/matlab-app-building/))

UI 컴포넌트, 레이아웃, 콜백, 웹 통합을 사용하여 프로그래밍 방식으로 MATLAB 앱 작성

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-apply-theme` | MATLAB 차트와 uifigure 앱에 색상 팔레트, 브랜드 테마, 다크 모드, 조건부 스타일을 적용합니다. |
| `matlab-build-app` | 가이드에 따라 UIFigure 또는 UIHTML 중에서 아키텍처를 선택하고 대표적인 레이아웃 패턴(layout archetype)과 구조화된 구현 계획을 활용하여 MATLAB 앱을 작성합니다. UIFigure 앱의 경우, 필요에 따라 앱 디자이너 형식(.mlapp 또는 일반 텍스트)으로 직렬화할 수 있습니다. |
| `matlab-build-chart` | 올바른 좌표축(axes) 처리, 최신 레이아웃, 주석, 상호작용 기능 및 애니메이션 패턴을 적용하여 MATLAB 차트를 생성하고 사용자 지정합니다. |

### MATLAB 데이터 가져오기 및 분석 ([`matlab-data-import-and-analysis`](../../skills-catalog/matlab-data-import-and-analysis/))

테이블, 타임테이블, 필터링, 집계, 시계열 연산을 사용하여 MATLAB에서 데이터 가져오기, 내보내기 및 분석

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-analyze-data` | 테이블, 타임테이블, 숫자형 배열, 그리드 데이터를 사용하여 MATLAB에서 데이터를 분석합니다. 여기에는 필터링, 집계(aggregation), 평활화(smoothing), 정리(cleaning), 시계열 연산이 포함됩니다. |
| `matlab-choose-big-data-solution` | 메모리에 맞지 않을 수 있는 대규모 테이블 형식 데이터를 처리하기에 적합한 MATLAB 툴을 선택합니다. |
| `matlab-import-export-data` | 툴 간 데이터 충실도(cross-tool fidelity)를 유지하면서 테이블 형식 데이터, 정형 데이터, 이진 데이터를 가져오고 내보냅니다. |
| `matlab-secure-credentials` | 내장된 MATLAB Vault를 사용하여 MATLAB에서 자격 증명을 안전하게 저장하고, 가져오고, 전달합니다. |

### MATLAB 환경 및 설정 ([`matlab-environment-and-settings`](../../skills-catalog/matlab-environment-and-settings/))

MATLAB 릴리스 간 설정 차이를 비교하고, 시작 스크립트(Startup Script)가 올바른 설정 경로를 사용하도록 마이그레이션

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-migrate-settings` | MATLAB 릴리스 간 설정을 비교하고, MATLAB 설정을 프로그래밍 방식으로 구성하는 MATLAB 코드 파일(.m)이 대상 릴리스에 맞는 올바른 설정 경로를 사용하도록 업데이트합니다. |

### MATLAB 외부 언어 인터페이스 ([`matlab-external-language-interfaces`](../../skills-catalog/matlab-external-language-interfaces/))

MATLAB에서 Python&reg; 라이브러리를 호출하고, MEX 파일을 interleaved complex API(실수부/허수부 결합형 복소수 API)로 업그레이드

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-call-python` | py. 인터페이스를 사용하여 MATLAB에서 Python 라이브러리를 호출합니다. |
| `matlab-upgrade-mex-ic` | C, C++ 및 Fortran MEX 파일을 separate complex API(실수부/허수부 분리형 복소수 API)에서 interleaved complex API로 변환하고, SC/IC 빌드를 위한 MX_HAS_INTERLEAVED_COMPLEX 가드를 적용하며, 성능 검증을 수행합니다.  |

### MATLAB 프로그래밍 ([`matlab-programming`](../../skills-catalog/matlab-programming/))

입력값 유효성을 검사하는 견고한 MATLAB 함수 작성

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-validate-function-arguments` | arguments 블록을 사용하여 MATLAB 함수 입력값의 유효성을 검사합니다. |

### MATLAB 소프트웨어 개발 ([`matlab-software-development`](../../skills-catalog/matlab-software-development/))

레거시 코드 현대화, 성능 및 메모리 최적화, 툴박스 문서화 및 생성, 프로젝트 생성, 빌드 계획 개발

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-instrument-opentelemetry-tracing` | 올바른 컨텍스트 전파 및 라이프사이클을 적용하여 MATLAB 함수에 OpenTelemetry 추적 스팬(tracing span)을 추가합니다. |
| `matlab-modernize-code` | 제거되었거나 권장되지 않는 MATLAB 함수와 패턴을 현대화합니다. |
| `matlab-optimize-memory` | 구조화된 측정-프로파일링-최적화-검증 워크플로를 사용하여 MATLAB 코드의 메모리 병목 현상을 찾아 해결합니다. |
| `matlab-optimize-performance` | MATLAB 코드의 성능을 최적화합니다. |
| `matlab-package-toolbox` | MATLAB 코드를 설치 가능한 .mltbx 툴박스로 패키징합니다. |
| `matlab-write-help` | MathWorks 문서화 표준에 따라 MATLAB 도움말 텍스트를 생성하거나 개선합니다. |
| `matlab-write-performance-tests` | matlab.perftest.TestCase 프레임워크를 사용하여 MATLAB 성능 테스트를 작성합니다. |

### 항공우주 ([`aerospace`](../../skills-catalog/aerospace/))

MATLAB, Aerospace Toolbox&trade; 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-compute-aerospace-environment` | Aerospace Toolbox 함수를 사용하여 항공우주 환경 속성(대기, 중력, 바람, 자기장, 지오이드, 우주 기상, 천체력(ephemeris), 지구 방향)을 계산합니다. |
| `matlab-convert-aerospace-coordinates` | 항공우주 좌표 프레임, 회전, 시간, 단위를 변환합니다. |

### AI 및 통계학 ([`ai-and-statistics`](../../skills-catalog/ai-and-statistics/))

MATLAB, Simulink, Curve Fitting Toolbox&trade;, Deep Learning Toolbox&trade;, Embedded Coder&trade;, Fixed-Point Designer&trade;, MATLAB Coder&trade;, MATLAB Compiler SDK&trade;, MATLAB Report Generator&trade;, Optimization Toolbox&trade;, Parallel Computing Toolbox&trade;, Statistics and Machine Learning Toolbox&trade;, Deep Learning Toolbox Converter for ONNX Model Format&trade;, Deep Learning Toolbox Converter for PyTorch Models&trade;, Deep Learning Toolbox Converter for TensorFlow Models&trade; 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-analyze-reliability` | 신뢰성 분석을 위해 수명 분포와 가속 수명 모델을 피팅합니다. |
| `matlab-classify-tabular-data` | 여러 후보 모델을 비교하고 통계적으로 동등한 최상위 모델군(top tier)을 식별하여 테이블 형식 데이터를 분류합니다. |
| `matlab-create-experiment` | 사용자 코드를 분석하고 적절한 함수와 하이퍼파라미터를 생성하여 실험 관리자 앱에서 실행할 실험을 만듭니다. |
| `matlab-deploy-embedded-ai` | MATLAB과 Simulink를 사용하여 AI 모델을 임베디드 하드웨어에 배포합니다. |
| `matlab-engineer-tabular-features` | MATLAB에서 단일 응답 변수에 대한 테이블 형식 분류 또는 회귀에 사용할 최적의 특징을 엔지니어링하고 선택합니다. |
| `matlab-fit-curve` | 곡선 피팅기 앱을 사용하여 대화형 방식으로 곡선과 곡면을 피팅합니다. |
| `matlab-import-external-ai-model` | PyTorch, ONNX, Keras 딥러닝 모델을 MATLAB으로 가져오고 수치적 정확성을 검증합니다. |
| `matlab-train-network` | 권장 API를 사용하여 신경망을 훈련, 평가하고 Simulink로 내보냅니다. 레거시 신경망 훈련 코드를 최신 대체 방식으로 마이그레이션합니다. |
| `matlab-use-machine-learning-apps` | 분류 학습기 앱과 회귀 학습기 앱을 사용하여 머신러닝 모델을 훈련시키고, 비교하고, 내보냅니다. |

### 자동차 ([`automotive`](../../skills-catalog/automotive/))

MATLAB, Simulink, Automated Driving Toolbox&trade;, Computer Vision Toolbox&trade;, RoadRunner, RoadRunner Scenario, RoadRunner Scene Builder, Sensor Fusion and Tracking Toolbox&trade;, Automated Driving Toolbox Interface for Eclipse SUMO Traffic Simulator&trade;, Scenario Builder for Automated Driving Toolbox&trade; 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-cosimulate-sumo-simulink` | Eclipse&trade; SUMO 교통 시뮬레이터와 연동 시뮬레이션하는 Simulink 모델을 구축합니다. |
| `matlab-import-driving-data` | 기록된 주행 센서 데이터(GPS, 카메라, 라이다, 액터 추적)를 scenariobuilder.* 객체로 가져오고, 시나리오 작성 전에 타임스탬프 동기화, 자르기, 오프셋, 정규화를 수행합니다. |
| `matlab-use-ncap-protocol` | Euro NCAP 테스트 시나리오와 변형 시나리오를 생성하고, 시뮬레이터 간 변환을 수행하고, 점수를 계산합니다. |
| `matlab-use-scenario-builder` | 기록된 센서 데이터를 기반으로 주행 장면(scene), 시나리오, 노면(road surface), 3D 에셋을 구축하고 RoadRunner, drivingScenario, OpenSCENARIO, OpenDRIVE, OpenCRG, Unreal Engine&reg;으로 내보냅니다. |
| `roadrunner-asset-mapping` | MATLAB에서 맵 형식 변환을 위한 RoadRunner 에셋 경로 룩업 테이블을 생성합니다. |
| `roadrunner-build-scenario-from-osc` | OpenSCENARIO 1.x 파일을 해석하고 해당 시나리오를 RoadRunner에서 프로그래밍 방식으로 재구성합니다. |
| `roadrunner-convert-lanelet2-to-rrhd` | MATLAB을 사용하여 Lanelet2 맵(.osm)을 RoadRunner HD Map(.rrhd) 형식으로 변환합니다. |
| `roadrunner-core` | MATLAB에서 RoadRunner에 연결하고 프로젝트, 장면, 시나리오 라이프사이클을 관리합니다. |
| `roadrunner-import-scene` | MATLAB에서 RoadRunner에 연결하고 HD Map 또는 OpenDRIVE 파일을 새 장면으로 가져옵니다. |
| `roadrunner-rrhd-authoring` | MATLAB에서 차선, 경계, 표식, 교차로, 표지판, 신호, 장벽, 주차장 등의 RoadRunner HD Map 엔터티를 구축합니다. |
| `roadrunner-scenario-authoring` | MATLAB에서 프로그래밍 방식으로 RoadRunner 주행 시나리오를 생성합니다. |
| `roadrunner-scenario-simulating` | MATLAB 및 Simulink 연동 시뮬레이션을 통해 프로그래밍 방식으로 RoadRunner 시나리오를 시뮬레이션합니다. |

### 클라우드 솔루션 ([`cloud-solutions`](../../skills-catalog/cloud-solutions/))

MATLAB, MATLAB Drive&trade; 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-share-content` | MATLAB 콘텐츠를 GitHub&reg;, MATLAB Drive, File Exchange에 업로드하고 "MATLAB Online&trade;에서 열기" URL을 생성하여 공유합니다. |

### 코드 생성 ([`code-generation`](../../skills-catalog/code-generation/))

MATLAB, Embedded Coder, Fixed-Point Designer, GPU Coder&trade;, MATLAB Coder, MATLAB Test&trade;, Parallel Computing Toolbox, MATLAB Coder Support Package for PyTorch and LiteRT Models&trade; 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-deploy-ai-model` | loadPyTorchExportedProgram, loadLiteRTModel, codegen을 사용하여 PyTorch ExportedProgram(.pt2) 또는 LiteRT(.tflite) 모델에서 C/C++ 또는 CUDA 코드를 생성합니다. Simulink 통합 워크플로를 포함합니다. |
| `matlab-deploy-embedded-code` | PIL 검증을 수행하여 MATLAB 생성 코드를 임베디드 하드웨어에 배포합니다. |
| `matlab-generate-code` | MATLAB Coder, Embedded Coder 또는 GPU Coder를 사용하여 MATLAB에서 C/C++ 또는 CUDA 코드를 생성, 검증하고 가속화합니다. |
| `matlab-optimize-gpu-codegen` | 더 빠른 CUDA 코드를 생성하기 위해 GPU Coder용으로 MATLAB 함수를 최적화합니다. |
| `matlab-review-fi-object-code` | MATLAB 고정소수점(fi) 코드의 성능, 코드 생성 효율성, 정확성을 검토합니다. |

### 계산 생물학 ([`computational-biology`](../../skills-catalog/computational-biology/))

MATLAB, SimBiology&trade;, Statistics and Machine Learning Toolbox 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `simbiology-build-model` | SimBiology 모델을 처음부터 구축하고, 기존 모델을 수정하고, 다이어그램 레이아웃을 생성합니다. |
| `simbiology-fit-model` | SimBiology 모델 파라미터를 데이터에 피팅합니다. |
| `simbiology-simulate-model` | SimBiology 모델에 대해 시뮬레이션을 실행하고, 파라미터 스윕, 가정 시나리오(what-if 시나리오) 탐색 및 민감도 분석을 수행합니다. |

### 계산 금융 ([`computational-finance`](../../skills-catalog/computational-finance/))

MATLAB, Datafeed Toolbox&trade;, Financial Instruments Toolbox&trade;, Financial Toolbox&trade;, Spreadsheet Link&trade; 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-access-datafeed` | Datafeed Toolbox를 사용하여 Bloomberg&reg;, FRED&reg;, Haver Analytics&reg;, LSEG&reg; Datastream에 연결하고 금융 및 경제 데이터를 가져옵니다. |
| `matlab-optimize-portfolio` | 평균-분산 포트폴리오 최적화 문제를 정식화하고 풉니다. |
| `matlab-price-instrument` | 몬테카를로, FFT 또는 금리 트리(interest-rate tree)를 사용하여 금융 상품 가격을 결정합니다. |
| `matlab-use-spreadsheet-link` | Spreadsheet Link를 사용하여 Excel과 데이터를 주고받기 위한 VBA 매크로와 워크시트 함수를 작성합니다. |

### 제어 시스템 ([`control-systems`](../../skills-catalog/control-systems/))

MATLAB, Control System Toolbox&trade;, Predictive Maintenance Toolbox&trade;, Signal Processing Toolbox&trade;, Statistics and Machine Learning Toolbox, System Identification Toolbox&trade; 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-extract-battery-features` | 열화(degradation) 및 성능(health) 분석을 위해 사이클링 테스트 데이터에서 배터리 특징을 추출합니다. |
| `matlab-extract-rotating-machinery-features` | 상태 모니터링 및 결함 검출을 위해 회전 기계 진동 데이터에서 특징을 추출합니다. |
| `matlab-identify-linear-system` | System Identification Toolbox를 사용하여 측정 데이터로부터 선형 동적 모델을 식별합니다. |

### 영상 처리 및 컴퓨터 비전 ([`image-processing-and-computer-vision`](../../skills-catalog/image-processing-and-computer-vision/))

MATLAB, Computer Vision Toolbox, Deep Learning Toolbox, Image Processing Toolbox&trade;, Lidar Toolbox&trade;, Medical Imaging Toolbox&trade;, Optical Design and Simulation Library for Image Processing Toolbox&trade; 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-analyze-spectral-images` | 초분광(hyperspectral) 및 다중분광(multispectral) 영상을 읽고, 처리하고, 분석하고, 레이블을 지정하고, 분류합니다. |
| `matlab-display-image` | 영상 처리, 컴퓨터 비전, 외관 검사(visual inspection)를 위해 영상과 주석을 표시합니다. |
| `matlab-display-volume` | 3차원 영상 처리를 위해 3차원 영상 볼륨, 의료 영상 볼륨, 곡면 메시, 주석을 표시합니다. |
| `matlab-integrate-pytorch-vision` | MPyReq를 사용하여 GitHub 리포지토리 또는 pip 패키지의 Python 영상 처리 및 컴퓨터 비전 모델을 MATLAB과 연동하는 인터페이스를 만듭니다. |
| `matlab-model-optics` | Optical Design and Simulation Library를 사용하여 광학 시스템 및 광학 코팅을 구축하고, 가져오고, 분석하고, 최적화하고, 공차 분석(tolerance)을 수행합니다. |
| `matlab-process-large-images` | blockedImage를 사용하여 대용량 영상을 처리합니다. |
| `matlab-read-medical-data` | Image Processing Toolbox 및 Medical Imaging Toolbox API를 사용하여 의료 영상 데이터(DICOM, NIfTI, NRRD)를 읽고, 쓰고, 조작합니다. |
| `matlab-read-write-point-cloud-file` | PLY, PCD, LAS/LAZ, PCAP, E57, IDC 형식으로 3차원 포인트 클라우드 데이터를 읽고 씁니다. |
| `matlab-recognize-text` | ocr() 함수를 사용하여 MATLAB에서 OCR 파이프라인을 구축합니다. |
| `matlab-register-point-clouds` | ICP, NDT, LOAM, FGR, 위상 상관(phase correlation), CPD 알고리즘을 사용하여 3차원 포인트 클라우드를 정합 및 정렬합니다. |

### 수학 및 최적화 ([`math-and-optimization`](../../skills-catalog/math-and-optimization/))

MATLAB, Optimization Toolbox, Partial Differential Equation Toolbox&trade;, Symbolic Math Toolbox&trade; 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-solve-optimization` | 문제 기반 및 솔버 기반 접근 방식을 사용하여 MATLAB 최적화 문제를 정식화하고, 풀고, 검증합니다. |
| `matlab-solve-pde` | PDE Toolbox&trade;를 사용하여 열(thermal) 해석 문제, 구조(structural) 해석 문제, 전자기(electromagnetic) 해석 문제를 위한 유한요소 모델을 구축하고 풉니다. |
| `matlab-use-symbolic-math` | Symbolic Math Toolbox를 사용하여 해석적 해, 방정식 풀이, 미적분, 변환 및 코드 생성을 위한 올바른 MATLAB 코드를 생성합니다. |

### 병렬 연산 ([`parallel-computing`](../../skills-catalog/parallel-computing/))

MATLAB, Parallel Computing Toolbox, MATLAB Parallel Server&trade; 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-diagnose-parfor` | MATLAB의 parfor 변수 분류 오류를 진단하고 해결합니다. |
| `matlab-discover-clusters` | 병렬 연산 클러스터를 검색하고 클러스터 프로파일을 관리합니다. |
| `matlab-set-up-worker-state` | 병렬 풀을 위한 워커 환경 및 워커별 상태를 설정합니다. |
| `matlab-setup-gpu` | MATLAB GPU 연산을 위한 GPU 가용성을 감지하고 검증합니다. |
| `matlab-use-thread-pool` | 스레드 기반 병렬 풀을 사용하여 로컬 병렬 연산 속도를 향상시킵니다. |

### 레이다 ([`radar`](../../skills-catalog/radar/))

MATLAB, Mapping Toolbox&trade;, Phased Array System Toolbox&trade;, Radar Toolbox&trade;, Sensor Fusion and Tracking Toolbox, Signal Processing Toolbox 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-design-radar-waveform` | Phased Array System Toolbox를 사용하여 레이다 및 소나 파형을 설계하고, 선택하고, 분석합니다. |
| `matlab-design-radar` | 레이다 디자이너 앱에서 레이다 시스템을 설계하고, 구성하고, 분석합니다. |
| `matlab-import-tracking-data` | 원시 추적 데이터(CSV, XLSX, TXT 또는 MATLAB 테이블)를 Sensor Fusion and Tracking Toolbox에서 사용되는 objectDetection 배열 및 objectTrack 배열로 가져옵니다. |
| `matlab-simulate-radar-detections` | 감시 및 추적 레이다 시나리오를 위한 통계적 레이다 검출을 시뮬레이션합니다. |

### 리포팅 및 데이터베이스 액세스 ([`reporting-and-database-access`](../../skills-catalog/reporting-and-database-access/))

MATLAB, Database Toolbox&trade;, MATLAB Report Generator, Parallel Computing Toolbox, Simulink Report Generator&trade; 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-connect-databricks` | Spark 또는 JDBC를 통해 MATLAB을 Databricks&reg;에 연결하여 데이터를 읽고 씁니다. |
| `matlab-generate-report` | Report Generator API를 사용하여 MATLAB 데이터와 Simulink 모델로부터 구조화된 PDF, Word, HTML 리포트를 생성합니다. |
| `matlab-use-database` | MATLAB에서 관계형 데이터베이스를 읽고, 쓰고, 업데이트하고, 관리합니다. |
| `matlab-use-duckdb` | DuckDB를 MATLAB에서 대규모 테이블 형식 파일에 대한 비수학 연산(non-math operations) 엔진이자 별도 구성이 필요 없는 임베디드 데이터베이스로 사용합니다. pre-flight routing, operations boundaries 및 profile-operate-close 워크플로를 포함합니다. |

### RF 및 혼성 신호 ([`rf-and-mixed-signal`](../../skills-catalog/rf-and-mixed-signal/))

MATLAB, Simulink, Antenna Toolbox&trade;, Mixed-Signal Blockset&trade;, RF Blockset&trade;, RF PCB Toolbox&trade;, RF Toolbox&trade;, SerDes Toolbox&trade;, Signal Integrity Toolbox, Signal Processing Toolbox, Statistics and Machine Learning Toolbox 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-analyze-ams-waveform` | Mixed-Signal Blockset를 사용하여 AMS 시뮬레이션 파형으로부터 위상 잡음(phase noise), 지터(jitter) 및 타이밍을 측정합니다. |
| `matlab-analyze-antenna-structures` | 전기적으로 큰 안테나 구조인 반사기(reflector), 반사배열(reflectarray), 플랫폼 장착 안테나, 레이다 반사 면적(radar cross section)을 설계하고 분석합니다. |
| `matlab-analyze-em` | RF PCB 성능 검증을 위해 S-파라미터, 삽입 손실, 전자기장, 전류를 계산합니다. |
| `matlab-analyze-pcb-pdn` | PCB 레이아웃에서 PDN DC 전압 및 전류 분포, IR 강하(IR drop), 설계 규칙 검사를 분석합니다. |
| `matlab-assemble-pcb-layout` | pcbComponent, 형상(shape), 부울 연산, 급전(feed), 다층 적층 구조(multi-layer stackup)를 사용하여 사용자 지정 PCB 구조를 구축합니다. |
| `matlab-design-antenna` | MATLAB Antenna Toolbox를 사용하여 안테나, 배열 및 PCB 안테나를 설계합니다. 카탈로그 안테나 설계, 사용자 지정 안테나 구성, PCB 안테나 설계, 유한 배열과 무한 배열, AI 기반 설계 탐색, 최적화를 다룹니다. |
| `matlab-design-pcb-coupler` | Wilkinson, branchline, ratrace, directional coupler(방향성 커플러), corporate divider(분배기), Rotman lens(Rotman 렌즈)를 설계합니다. |
| `matlab-design-pcb-filter` | hairpin, coupled-line(결합 선로), combline, stub 및 SIW 토폴로지를 사용하여 대역통과, 저역통과, 대역저지 RF 필터를 설계합니다. |
| `matlab-design-pcb-passive` | RF 회로용 나선형 인덕터(spiral inductor), 인터디지털 커패시터(interdigital capacitor), 발룬(balun), 공진기(resonator), 위상 변환기(phase shifter)를 설계합니다. |
| `matlab-design-pcb-transmission-line` | 임피던스 제어 및 누화(crosstalk) 분석을 적용하여 마이크로스트립(microstrip), 스트립라인(stripline), CPW, 차동 쌍(differential pair) 전송 선로를 설계합니다. |
| `matlab-export-session-script` | 대화 과정에서 생성된 MATLAB 코드를 정리하여 실행 가능한 .m 스크립트로 내보냅니다. |
| `matlab-integrate-antenna` | MATLAB Antenna Toolbox 및 RF Toolbox를 사용하여 안테나를 RF 시스템에 통합합니다. 임피던스 정합 네트워크 설계, 측정 데이터 기반 안테나 생성(measured antenna creation), RF 전파 및 사이트 계획, SAR 추정을 다룹니다. |
| `matlab-integrate-pcb-circuit` | PCB 컴포넌트를 캐스케이드 연결하고, 집중 소자를 추가하고, 다중 컴포넌트 RF 회로용 Touchstone 파일을 내보냅니다. |
| `matlab-manage-pcb-material` | RF PCB 시뮬레이션을 위한 유전체 기판(dielectric substrate), 금속 도체, 다층 적층 구조, 손실 모델을 정의합니다. |
| `matlab-model-ams-systems` | Mixed-Signal Blockset를 사용하여 IC 데이터시트 또는 시스템 사양으로부터 PLL 주파수 합성기(frequency synthesizer)를 모델링합니다. 파라미터를 추출하고, 아키텍처를 선택하고, Simulink 모델을 구성하고, 루프 필터를 설계하고, 위상 잡음을 검증합니다. |
| `matlab-model-rf` | RF Toolbox 및 RF Blockset을 사용하여 MATLAB에서 RF 시스템을 설계, 분석, 시뮬레이션합니다. S-파라미터 I/O부터 전체 Circuit Envelope(회로 포락선) 시간 영역 시뮬레이션까지 다룹니다. |
| `matlab-model-serdes-systems` | MATLAB SerDes Toolbox를 사용하여 Serializer/Deserializer(SerDes) 시스템(직렬 및 병렬 링크)을 모델링하고, 시뮬레이션하고, 최적화합니다. |
| `matlab-model-via` | 고속 PCB 층간 전환(layer transition)을 위해 패드(pad), 안티패드(antipad), 접지 리턴 비아(ground return via)를 포함한 비아(via)를 모델링합니다. |
| `matlab-optimize-pcb-design` | patternsearch 및 surrogateopt를 사용하여 대역폭, 반사 손실, 면적을 기준으로 RF PCB 컴포넌트의 치수를 최적화합니다. |
| `matlab-read-pcb-layout` | Gerber, ODB++, Allegro .brd 파일을 가져오고 네트(net), 층(layer), 형상(shape), 적층 구조(stackup)를 검사합니다. |
| `matlab-write-pcb-layout` | PCB 제조를 위해 pcbComponent 설계를 Gerber 파일로 내보냅니다. |

### 로보틱스 및 자율 시스템 ([`robotics-and-autonomous-systems`](../../skills-catalog/robotics-and-autonomous-systems/))

MATLAB, Navigation Toolbox&trade;, UAV Toolbox&trade;, Robotics System Toolbox&trade; 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-compute-gnss-position` | rinexread, gnssmeasurements, receiverposition, gnssoptions를 사용하여 RINEX v3 데이터로부터 다중 위성군 GPS(Global Positioning System) 또는 GNSS(Global Navigation Satellite System) 위치를 계산합니다. |
| `matlab-connect-mavlink` | MATLAB과 PX4 또는 ArduPilot 비행 제어기 간에 MAVLink 연결을 설정합니다. |
| `matlab-create-uav-scenario` | 지형, 건물, 센서 탑재 플랫폼, 3차원 시각화가 포함된 UAV 시나리오를 생성하고 시뮬레이션합니다. |
| `matlab-fuse-inertial-sensors` | 센서 구성을 분석하고 MATLAB Navigation Toolbox에서 관성 융합 필터를 생성합니다. |
| `matlab-model-robot-kinematics` | MATLAB에서 매니퓰레이터 모델을 구축하고 기구학 해(kinematic solution)를 검증합니다. |
| `matlab-plan-robot-motion` | 충돌 없는 매니퓰레이터 모션을 계획하고 시간 기반으로 파라미터화된(time-parameterized) 궤적을 생성합니다. |

### 신호 처리 ([`signal-processing`](../../skills-catalog/signal-processing/))

MATLAB, Simulink, Audio Toolbox&trade;, DSP HDL Toolbox&trade;, DSP System Toolbox&trade;, Fixed-Point Designer, HDL Coder&trade;, Signal Processing Toolbox, Wavelet Toolbox&trade; 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-analyze-spectrum` | 비모수(nonparametric) 및 모수(parametric) 추정기를 사용하여 신호 스펙트럼을 분석합니다. |
| `matlab-analyze-time-frequency-content` | CWT, STFT, 싱크로스퀴징(synchrosqueezing), 웨이블릿 코히어런스(wavelet coherence)를 사용하여 시간-주파수 성분을 분석합니다. |
| `matlab-configure-scope-object` | 스코프 관련 Simulink 블록 또는 MATLAB 객체의 속성을 구성합니다. |
| `matlab-design-adaptive-filter` | System Object를 사용하여 적응 필터를 설계하고 구현합니다. |
| `matlab-design-digital-filter` | MATLAB에서 디지털 필터를 설계하고 검증합니다. |
| `matlab-design-dsphdl-ddc` | dsphdl System Object를 사용하여 HDL 최적화 디지털 다운 컨버터(Digital Down Converter)를 설계합니다. |
| `matlab-extract-signal-features` | 1차원 신호로부터 프레임별 시간, 주파수, 시간-주파수 특징을 추출합니다. |
| `matlab-play-record-audio` | audiostreamer를 사용하여 MATLAB에서 오디오를 재생하고 녹음합니다. |
| `matlab-prepare-signal-data` | 원시 신호를 전처리(누락된 구간 채우기, 추세 제거, 이상값 제거, 잡음 제거, 리샘플링/정렬)하고 ML 훈련을 위한 signalDatastore 파이프라인을 구축합니다. 여기에는 레이블 지정, 층화 분할(stratified split), 프레임 분할(framing), 병렬 읽기(parallel read), trainnet 전달(hand-off)이 포함됩니다. |
| `matlab-process-streaming-audio` | Audio Toolbox 스트리밍 객체를 사용하여 실시간 오디오 처리 체인을 설계하고 실행합니다. |
| `matlab-write-audio-plugin` | validateAudioPlugin 및 generateAudioPlugin을 통해 VST/AU로 컴파일되는 Audio Toolbox 플러그인을 작성합니다. |

### 테스트 및 계측 ([`test-and-measurement`](../../skills-catalog/test-and-measurement/))

MATLAB, Data Acquisition Toolbox&trade;, Image Acquisition Toolbox&trade;, Image Processing Toolbox, Industrial Communication Toolbox&trade;, Vehicle Network Toolbox&trade;, MATLAB Support Package for Arduino Hardware&trade; 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-build-industrial-hmi` | MATLAB에서 ISA-101 규약을 준수하는 산업용 SCADA/HMI 대시보드를 구축합니다. 사용 가능한 경우 직렬화(serialization)를 matlab-build-app에 위임하여 실제 앱 디자이너 앱(.mlapp)을 생성하고, 그렇지 않은 경우 프로그래밍 방식의 .m 앱으로 대체합니다. |
| `matlab-call-nidaqmx` | NI-DAQmx C 함수를 올바른 calldaqlib MATLAB 호출로 변환합니다. |
| `matlab-connect-arduino` | USB를 통해 MATLAB에서 Arduino&reg; 보드를 검색하고, 구성하고, 연결합니다. |
| `matlab-connect-bluetooth-low-energy-device` | MATLAB에서 Bluetooth Low Energy 주변 기기를 검색하고 연결합니다. |
| `matlab-create-custom-arduino-library` | MATLAB에서 지원되지 않는 센서 및 주변 기기에 액세스하기 위해 사용자 지정 Arduino 애드온 라이브러리를 만듭니다. |
| `matlab-discover-hardware` | 헬퍼 함수를 통해 MATLAB이 지원하는 하드웨어 장치를 검색하고, 검사하고, 설정합니다. |
| `matlab-enhance-camera-image` | Image Acquisition Toolbox를 통해 연결된 카메라의 영상 품질을 진단하고 개선합니다. |
| `matlab-find-pi-assets` | piclient 및 afclient를 사용하여 PI Data Archive 태그와 Asset Framework 요소를 찾고 쿼리합니다. |
| `matlab-import-export-vehicle-data` | 로그 파일(ASC, BLF, MDF, DAT, TXT)의 차량 네트워크 데이터를 가져오고, 디코딩하고, 내보내기합니다. 다형성 반환 유형(polymorphic return type)의 올바른 처리, CAN/CAN FD/LIN 디코드 파이프라인, MDF/BLF 쓰기 워크플로를 포함합니다. |
| `matlab-modernize-daq` | 레거시 세션 기반 Data Acquisition Toolbox 코드를 최신 DataAcquisition 인터페이스로 마이그레이션합니다. |
| `matlab-use-cameras` | Image Acquisition Toolbox의 videoinput 인터페이스를 사용하여 카메라에 연결하고 영상을 수집합니다. |
| `matlab-use-opcua-client` | OPC UA 서버를 검색하고, 보안 MATLAB 클라이언트 연결을 만들고, 서버 노드를 찾아보고 탐색합니다. |
| `matlab-use-vehicle-network` | MATLAB에서 Vehicle Network Toolbox를 사용하여 지원되는 모든 하드웨어 공급업체의 CAN/CAN FD 차량 네트워크 통신을 설정하고, 문제를 해결하고, 분석합니다. |

### 무선 통신 ([`wireless-communications`](../../skills-catalog/wireless-communications/))

MATLAB, 5G Toolbox&trade;, Bluetooth&reg; Toolbox&trade;, Communications Toolbox&trade;, Satellite Communications Toolbox&trade;, Wireless Network Toolbox&trade;, Wireless Testbench&trade;, WLAN Toolbox&trade;, Wireless Testbench Support Package for NI USRP Radios&trade; 지원

| 스킬 | 에이전트에 가르치는 내용 |
|-------|---------------------------|
| `matlab-add-awgn` | 통신 시뮬레이션을 위해 가산성 백색 가우스 잡음(AWGN)을 추가하고, SNR, Eb/No, Es/No, 부반송파당 SNR(per-subcarrier SNR) 간에 변환합니다. |
| `matlab-design-ofdm-system` | ofdmmod/ofdmdemod를 사용하여 사용자 지정 OFDM 시스템을 설계하고 시뮬레이션합니다. 페이딩 채널 구성, 이퀄라이제이션, 동기화(타이밍/CFO), LDPC 코딩, SNR 처리, 부반송파 할당, 파일럿 기반 채널 추정을 포함합니다. |
| `matlab-generate-5g-waveform` | 3GPP를 준수하는 5G NR 다운링크 및 업링크 기저대역 파형을 생성합니다. |
| `matlab-generate-ble-waveform` | Bluetooth Low Energy PHY 파형을 생성하고 분석합니다. |
| `matlab-generate-gnss-waveform` | Satellite Communications Toolbox를 사용하여 물리적으로 현실적인 채널 손상 또는 사용자 지정된 채널 손상이 포함된 GNSS 기저대역 파형(GPS, Galileo, NavIC)을 생성합니다. |
| `matlab-generate-wlan-waveform` | 표준을 준수하는 IEEE 802.11 WLAN 파형을 생성합니다. |
| `matlab-set-up-usrp-radio` | Wireless Testbench에서 NI USRP 라디오를 사용할 수 있도록 설정하고 검증합니다. |
| `matlab-simulate-bluetooth-network` | BLE, Classic BR/EDR, LE Audio를 포함한 Bluetooth 시스템 수준 네트워크를 시뮬레이션합니다. |
| `matlab-simulate-wireless-network` | wirelessNetworkSimulator를 사용하여 무선 네트워크 시뮬레이션을 설정하고 실행합니다. |
| `matlab-transmit-capture-usrp` | Wireless Testbench에서 NI USRP 라디오를 사용하여 RF 파형을 송신하고 캡처합니다. |

<!-- END SKILLS -->

## 스킬 설치 방법

스킬 설치 방법에 대한 자세한 내용은
[MATLAB Agentic Toolkit 설치](../README.ko.md#matlab-agentic-toolkit-설치)를 참조하십시오.

----

Copyright 2026 The MathWorks, Inc.

----
