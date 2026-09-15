<!--
Source English Markdown:
- File: ./skills-catalog/README.md
- Branch: main
- Commit: cd7a55815df574409a09d14d6333641cc86cff3e
-->

# スキル カタログ

<p align="center">
  <a href="../../skills-catalog/README.md">English</a> •
  <a href="README.es.md">Español</a> •
  日本語 •
  <a href="README.ko.md">한국어</a> •
  <a href="README.zh-cn.md">简体中文</a>
</p>

スキル カタログはエージェント スキルをグループに整理します。各グループには 1 つ以上のスキル フォルダーがあり、それぞれに `SKILL.md` ファイルと `manifest.yaml` ファイルが含まれています。`manifest.yaml` ファイルにはスキルに関するメタデータが含まれています。

## スキル

<!-- BEGIN SKILLS -->
### MATLAB 基本機能 ([`matlab-core`](../../skills-catalog/matlab-core/))

MATLAB&reg; コードとインストールの作成、デバッグ、テスト、レビュー、管理

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-create-live-script` | リッチテキスト、LaTeX 式、インライン図を含むプレーンテキストの MATLAB ライブ スクリプトを作成する。 |
| `matlab-debug-code` | MATLAB のエラーと予期しない動作を診断する。 |
| `matlab-install-products` | MATLAB パッケージ マネージャー (mpm) を使用してコマンド ラインから MathWorks&reg; 製品をインストールする。 |
| `matlab-list-products` | 指定した MATLAB インストール フォルダーにインストールされているすべての MATLAB 製品とサポート パッケージを表示する。 |
| `matlab-read-documentation` | 使用中の MATLAB リリースに固有の MathWorks ドキュメントを取得して参照し、正しい関数構文、完全なワークフロー、MATLAB および Simulink&reg; ソフトウェアでのベスト プラクティスを確認する。 |
| `matlab-review-code` | MATLAB コードの品質、パフォーマンス、保守性、MathWorks コーディング規約への準拠をレビューする。 |
| `matlab-run-tests` | MATLAB テスト スイートを実行し、コード カバレッジを収集して、CI/CD パイプラインを構成する。 |
| `matlab-write-tests` | クラスベースのテスト フレームワークを使用して MATLAB ユニット テストを生成および構造化する。 |

### MATLAB アプリ作成 ([`matlab-app-building`](../../skills-catalog/matlab-app-building/))

UI コンポーネント、レイアウト、コールバック、Web 統合を使用して MATLAB アプリをプログラムで作成

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-apply-theme` | カラー パレット、ブランド テーマ、ダーク モード、条件付きスタイルを MATLAB チャートおよび uifigure アプリに適用する。 |
| `matlab-build-app` | ガイド付きアーキテクチャ選択 (UIFigure または UIHTML)、レイアウト アーキタイプ、構造化された実装計画で MATLAB アプリを作成する。UIFigure アプリの場合、オプションで App Designer 形式 (.mlapp またはプレーンテキスト) にシリアライズする。 |
| `matlab-build-chart` | 適切な軸処理、モダンなレイアウト、注釈、対話機能、アニメーション パターンで MATLAB チャートを作成およびカスタマイズする。 |

### MATLAB データ インポートと解析 ([`matlab-data-import-and-analysis`](../../skills-catalog/matlab-data-import-and-analysis/))

table、timetable、フィルタリング、集計、時系列演算を使用した MATLAB でのデータのインポート、エクスポート、解析

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-analyze-data` | table、timetable、数値配列、グリッド データを使用して MATLAB でデータを解析する。フィルタリング、集計、平滑化、クリーニング、時系列演算。 |
| `matlab-choose-big-data-solution` | メモリに収まらない可能性のある大規模な表形式データを処理するための適切な MATLAB ツールを選択する。 |
| `matlab-import-export-data` | ツール間でのデータ整合性を維持して表形式、構造化、バイナリ データをインポートおよびエクスポートする。 |
| `matlab-secure-credentials` | 組み込みの MATLAB Vault を使用して MATLAB で安全に資格情報を保存、取得、渡す。 |

### MATLAB 環境と設定 ([`matlab-environment-and-settings`](../../skills-catalog/matlab-environment-and-settings/))

リリース間の MATLAB 設定の差分比較とスタートアップ スクリプトの正しい設定パスへの移行

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-migrate-settings` | リリース間の MATLAB 設定を比較し、ターゲット リリースの正しい設定パスを使用するように、MATLAB 設定をプログラム的に構成する MATLAB コード ファイル (.m) を更新する。 |

### MATLAB 外部言語インターフェイス ([`matlab-external-language-interfaces`](../../skills-catalog/matlab-external-language-interfaces/))

MATLAB から Python&reg; ライブラリを呼び出し、MEX ファイルをインターリーブされた複素数 API にアップグレード

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-call-python` | py. インターフェイスを使用して MATLAB から Python ライブラリを呼び出す。 |
| `matlab-upgrade-mex-ic` | C、C++、Fortran MEX ファイルを実数/虚数分離型複素数 API からインターリーブされた複素数 API に変換し、SC/IC ビルドおよびパフォーマンス検証用に MX_HAS_INTERLEAVED_COMPLEX ガードを追加する。 |

### MATLAB プログラミング ([`matlab-programming`](../../skills-catalog/matlab-programming/))

入力検証を備えた堅牢な MATLAB 関数の記述

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-validate-function-arguments` | arguments ブロックを使用して MATLAB 関数の入力を検証する。 |

### MATLAB ソフトウェア開発 ([`matlab-software-development`](../../skills-catalog/matlab-software-development/))

レガシ コードの最新化、パフォーマンスとメモリの最適化、ドキュメント作成とツールボックスの作成、プロジェクトの作成、ビルド プランの作成

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-instrument-opentelemetry-tracing` | MATLAB 関数に、正しいコンテキスト伝播とライフサイクル管理を備えた  OpenTelemetry トレーシング スパンを追加する。 |
| `matlab-modernize-code` | 削除または非推奨の MATLAB 関数とパターンを最新化する。 |
| `matlab-optimize-memory` | 構造化された測定、プロファイリング、最適化、および検証から成るワークフローを使用して MATLAB コードのメモリ ボトルネックを見つけて修正する。 |
| `matlab-optimize-performance` | MATLAB コードのパフォーマンスを最適化する。 |
| `matlab-package-toolbox` | MATLAB コードをインストール可能な .mltbx ツールボックスとしてパッケージ化する。 |
| `matlab-write-help` | MathWorks ドキュメント標準に従って MATLAB ヘルプ テキストを生成または改善する。 |
| `matlab-write-performance-tests` | matlab.perftest.TestCase フレームワークを使用して MATLAB パフォーマンス テストを記述する。 |

### 航空宇宙関連 ([`aerospace`](../../skills-catalog/aerospace/))

MATLAB、Aerospace Toolbox&trade; をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-compute-aerospace-environment` | Aerospace Toolbox 関数を使用して航空宇宙環境特性 (大気、重力、風、磁場、ジオイド、宇宙天気、エフェメリス、地球姿勢) を計算する。 |
| `matlab-convert-aerospace-coordinates` | 航空宇宙座標系、回転、時間、単位を変換する。 |

### AI および統計 ([`ai-and-statistics`](../../skills-catalog/ai-and-statistics/))

MATLAB、Simulink、Curve Fitting Toolbox&trade;、Deep Learning Toolbox&trade;、Embedded Coder&trade;、Fixed-Point Designer&trade;、MATLAB Coder&trade;、MATLAB Compiler SDK&trade;、MATLAB Report Generator&trade;、Optimization Toolbox&trade;、Parallel Computing Toolbox&trade;、Statistics and Machine Learning Toolbox&trade;、Deep Learning Toolbox Converter for ONNX Model Format&trade;、Deep Learning Toolbox Converter for PyTorch Models&trade;、Deep Learning Toolbox Converter for TensorFlow Models&trade; をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-analyze-reliability` | 信頼性分析のために寿命分布モデルと加速寿命モデルを当てはめる。 |
| `matlab-classify-tabular-data` | 候補モデルを比較し、統計的に同等な上位モデル群を特定して表形式データを分類する。 |
| `matlab-create-experiment` | ユーザー コードを分析し、適切な関数とハイパーパラメーターを生成して実験マネージャー アプリ用の実験を作成する。 |
| `matlab-deploy-embedded-ai` | MATLAB と Simulink を使用して AI モデルを組み込みハードウェアにデプロイする。 |
| `matlab-engineer-tabular-features` | MATLAB で単一応答の表形式分類または回帰に最適な特徴量を作成・選択する。 |
| `matlab-fit-curve` | 曲線フィッター アプリを使用して対話的に曲線と曲面を当てはめる。 |
| `matlab-import-external-ai-model` | PyTorch、ONNX、Keras ディープ ラーニング モデルを MATLAB にインポートし、数値の正確性を検証する。 |
| `matlab-train-network` | 推奨 API を使用してニューラル ネットワークに学習させ、これを評価し、Simulink にエクスポートする。レガシのニューラル ネットワーク学習コードを最新の代替手段に移行する。 |
| `matlab-use-machine-learning-apps` | 分類学習器アプリおよび回帰学習器アプリを使用して機械学習モデルに学習させ、これを比較、エクスポートする。 |

### 自動車関連 ([`automotive`](../../skills-catalog/automotive/))

MATLAB、Simulink、Automated Driving Toolbox&trade;、Computer Vision Toolbox&trade;、RoadRunner、RoadRunner Scenario、RoadRunner Scene Builder、Sensor Fusion and Tracking Toolbox&trade;、Automated Driving Toolbox Interface for Eclipse SUMO Traffic Simulator&trade;、Scenario Builder for Automated Driving Toolbox&trade; をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-cosimulate-sumo-simulink` | Eclipse&trade; SUMO Traffic Simulator とコシミュレーションする Simulink モデルを構築する。 |
| `matlab-import-driving-data` | 記録された運転センサー データ (GPS、カメラ、LiDAR、アクター トラック) を scenariobuilder.* オブジェクトにインポートし、シナリオ構築前にタイムスタンプを同期、トリミング、オフセット、正規化する。 |
| `matlab-use-ncap-protocol` | Euro NCAP テスト シナリオとバリアントを生成し、シミュレーター間で変換し、スコアを計算する。 |
| `matlab-use-scenario-builder` | 記録されたセンサー データから運転シーン、シナリオ、路面、3D アセットを構築し、RoadRunner、drivingScenario、OpenSCENARIO、OpenDRIVE、OpenCRG、Unreal Engine&reg; にエクスポートする。 |
| `roadrunner-asset-mapping` | MATLAB でマップ形式を変換するための RoadRunner アセット パス ルックアップ テーブルを生成する。 |
| `roadrunner-build-scenario-from-osc` | OpenSCENARIO 1.x ファイルを解釈し、RoadRunner でプログラム的にシナリオを再作成する。 |
| `roadrunner-convert-lanelet2-to-rrhd` | MATLAB を使用して Lanelet2 マップ (.osm) を RoadRunner HD Map (.rrhd) 形式に変換する。 |
| `roadrunner-core` | MATLAB から RoadRunner に接続し、プロジェクト、シーン、シナリオのライフサイクルを管理する。 |
| `roadrunner-import-scene` | RoadRunner に接続し、MATLAB を使用して HD Map または OpenDRIVE ファイルを新しいシーンにインポートする。 |
| `roadrunner-rrhd-authoring` | MATLAB で RoadRunner HD Map エンティティを構築する — レーン、境界、マーキング、ジャンクション、標識、信号、バリア、駐車場。 |
| `roadrunner-scenario-authoring` | MATLAB からプログラム的に RoadRunner 運転シナリオを作成する。 |
| `roadrunner-scenario-simulating` | MATLAB と Simulink のコシミュレーションを通じてプログラム的に RoadRunner シナリオのシミュレーションを実行する。 |

### クラウド ソリューション ([`cloud-solutions`](../../skills-catalog/cloud-solutions/))

MATLAB、MATLAB Drive&trade; をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-share-content` | MATLAB コンテンツを GitHub&reg;、MATLAB Drive、File Exchange にアップロードし、「Open in MATLAB Online&trade;」URL を生成して共有する。 |

### コード生成 ([`code-generation`](../../skills-catalog/code-generation/))

MATLAB、Embedded Coder、Fixed-Point Designer、GPU Coder&trade;、MATLAB Coder、MATLAB Test&trade;、Parallel Computing Toolbox、MATLAB Coder Support Package for PyTorch and LiteRT Models&trade; をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-deploy-ai-model` | loadPyTorchExportedProgram、loadLiteRTModel、codegen を使用して PyTorch ExportedProgram (.pt2) または LiteRT (.tflite) モデルから C/C++ または CUDA コードを生成する。Simulink 統合ワークフローを含む。 |
| `matlab-deploy-embedded-code` | PIL 検証を使用して MATLAB 生成コードを組み込みハードウェアにデプロイする。 |
| `matlab-generate-code` | MATLAB Coder、Embedded Coder、GPU Coder を使用して MATLAB から C/C++ または CUDA コードを生成、検証、高速化する。 |
| `matlab-optimize-gpu-codegen` | より高速な CUDA コードを生成するために GPU Coder 向けに MATLAB 関数を最適化する。 |
| `matlab-review-fi-object-code` | MATLAB の固定小数点 (fi) コードのパフォーマンス、コード生成効率、正確性をレビューする。 |

### 情報生命科学 ([`computational-biology`](../../skills-catalog/computational-biology/))

MATLAB、SimBiology&trade;、Statistics and Machine Learning Toolbox をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `simbiology-build-model` | SimBiology モデルをゼロから構築し、既存のモデルを変更し、ダイアグラム レイアウトを生成する。 |
| `simbiology-fit-model` | SimBiology モデルのパラメーターをデータにフィットさせる。 |
| `simbiology-simulate-model` | シミュレーションの実行、パラメーターのスイープ、what-if シナリオの探索、SimBiology モデルの感度分析を行う。 |

### 金融工学 ([`computational-finance`](../../skills-catalog/computational-finance/))

MATLAB、Datafeed Toolbox&trade;、Financial Instruments Toolbox&trade;、Financial Toolbox&trade;、Spreadsheet Link&trade; をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-access-datafeed` | Datafeed Toolbox を使用して Bloomberg&reg;、FRED&reg;、Haver Analytics&reg;、LSEG&reg; Datastream に接続し、金融・経済データを取得する。 |
| `matlab-optimize-portfolio` | 平均分散ポートフォリオ最適化問題を定式化し、求解する。 |
| `matlab-price-instrument` | モンテ カルロ、FFT、金利ツリーを使用して金融商品の価格を計算する。 |
| `matlab-use-spreadsheet-link` | Spreadsheet Link を使用して Excel とデータを交換するための VBA マクロとワークシート関数を記述する。 |

### 制御システム ([`control-systems`](../../skills-catalog/control-systems/))

MATLAB、Control System Toolbox&trade;、Predictive Maintenance Toolbox&trade;、Signal Processing Toolbox&trade;、Statistics and Machine Learning Toolbox、System Identification Toolbox&trade; をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-extract-battery-features` | 劣化および健全性の分析のためにサイクル テスト データからバッテリー特徴量を抽出する。 |
| `matlab-extract-rotating-machinery-features` | 状態監視および故障検出のために回転機械振動データから特徴量を抽出する。 |
| `matlab-identify-linear-system` | System Identification Toolbox を使用して計測データから線形動的モデルを同定する。 |

### イメージ処理とコンピューター ビジョン ([`image-processing-and-computer-vision`](../../skills-catalog/image-processing-and-computer-vision/))

MATLAB、Computer Vision Toolbox、Deep Learning Toolbox、Image Processing Toolbox&trade;、Lidar Toolbox&trade;、Medical Imaging Toolbox&trade;、Optical Design and Simulation Library for Image Processing Toolbox&trade; をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-analyze-spectral-images` | ハイパースペクトル イメージとマルチスペクトル イメージを読み込み、処理、分析、ラベル付け、分類する。 |
| `matlab-display-image` | イメージ処理、コンピューター ビジョン、目視検査のための画像とアノテーションを表示する。 |
| `matlab-display-volume` | 3D イメージ処理のための 3D イメージ ボリューム、医用画像ボリューム、サーフェス メッシュ、アノテーションを表示する。 |
| `matlab-integrate-pytorch-vision` | MPyReq を使用して GitHub リポジトリまたは pip パッケージの Python イメージ処理およびコンピューター ビジョン モデル用の MATLAB インターフェースを作成する。 |
| `matlab-model-optics` | Optical Design and Simulation Library を使用して光学系とコーティングを構築、インポート、分析、最適化、公差解析を行う。 |
| `matlab-process-large-images` | blockedImage を使用して大きなイメージを処理する。 |
| `matlab-read-medical-data` | Image Processing Toolbox と Medical Imaging Toolbox API を使用して医用画像データ (DICOM、NIfTI、NRRD) の読み書きおよび操作を行う。 |
| `matlab-read-write-point-cloud-file` | PLY、PCD、LAS/LAZ、PCAP、E57、IDC 形式で 3D 点群データを読み書きする。 |
| `matlab-recognize-text` | ocr() 関数を使用して MATLAB で OCR パイプラインを構築する。 |
| `matlab-register-point-clouds` | ICP、NDT、LOAM、FGR、位相相関、CPD アルゴリズムを使用して 3D 点群の位置合わせを行う。 |

### 数学および最適化 ([`math-and-optimization`](../../skills-catalog/math-and-optimization/))

MATLAB、Optimization Toolbox、Partial Differential Equation Toolbox&trade;、Symbolic Math Toolbox&trade; をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-solve-optimization` | 問題ベースおよびソルバーベースのアプローチを使用して MATLAB 最適化問題を定式化、求解、検証する。 |
| `matlab-solve-pde` | PDE Toolbox&trade; を使用して熱、構造、電磁の問題の有限要素モデルを構築し、解決する。 |
| `matlab-use-symbolic-math` | Symbolic Math Toolbox を使用して、解析解の導出、方程式の解法、微積分、変換、コード生成のための正確な MATLAB コードを生成する。 |

### 並列計算 ([`parallel-computing`](../../skills-catalog/parallel-computing/))

MATLAB、Parallel Computing Toolbox、MATLAB Parallel Server&trade; をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-diagnose-parfor` | MATLAB の parfor 変数分類エラーを診断および修正する。 |
| `matlab-discover-clusters` | 並列計算クラスターを検出し、クラスター プロファイルを管理する。 |
| `matlab-set-up-worker-state` | 並列プール用のワーカー環境とワーカーごとの状態を設定する。 |
| `matlab-setup-gpu` | MATLAB GPU コンピューティング用の GPU の可用性を検出および検証する。 |
| `matlab-use-thread-pool` | スレッド ベースの並列プールを使用してローカル並列計算を高速化する。 |

### レーダー ([`radar`](../../skills-catalog/radar/))

MATLAB、Mapping Toolbox&trade;、Phased Array System Toolbox&trade;、Radar Toolbox&trade;、Sensor Fusion and Tracking Toolbox、Signal Processing Toolbox をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-design-radar-waveform` | Phased Array System Toolbox を使用してレーダーおよびソナー波形を設計、選択、分析する。 |
| `matlab-design-radar` | レーダー デザイナー アプリでレーダー システムを設計、構成、分析する。 |
| `matlab-import-tracking-data` | 生のトラッキング データ (CSV、XLSX、TXT、または MATLAB table) を Sensor Fusion and Tracking Toolbox で使用される objectDetection 配列と objectTrack 配列にインポートする。 |
| `matlab-simulate-radar-detections` | 監視およびトラッキング レーダー シナリオの統計的なレーダー検出をシミュレーションする。 |

### レポートとデータベース アクセス ([`reporting-and-database-access`](../../skills-catalog/reporting-and-database-access/))

MATLAB、Database Toolbox&trade;、MATLAB Report Generator、Parallel Computing Toolbox、Simulink Report Generator&trade; をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-connect-databricks` | Spark または JDBC を介して MATLAB を Databricks&reg; に接続し、データの読み書きを行う。 |
| `matlab-generate-report` | Report Generator API を使用して MATLAB データと Simulink モデルから構造化された PDF、Word、HTML レポートを生成する。 |
| `matlab-use-database` | MATLAB からリレーショナル データベースの読み書き、更新、管理を行う。 |
| `matlab-use-duckdb` | 大きな表形式ファイルに対する非数学演算用エンジンとして、また構成不要の組み込みデータベースとして MATLAB から DuckDB を使用する。事前チェックによるルーティング、操作の境界、プロファイル-操作-クローズのワークフローを含む。 |

### RF およびミックスド シグナル ([`rf-and-mixed-signal`](../../skills-catalog/rf-and-mixed-signal/))

MATLAB、Simulink、Antenna Toolbox&trade;、Mixed-Signal Blockset&trade;、RF Blockset&trade;、RF PCB Toolbox&trade;、RF Toolbox&trade;、SerDes Toolbox&trade;、Signal Integrity Toolbox、Signal Processing Toolbox、Statistics and Machine Learning Toolbox をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-analyze-ams-waveform` | Mixed-Signal Blockset を使用して AMS シミュレーション波形から位相ノイズ、ジッター、タイミングを測定する。 |
| `matlab-analyze-antenna-structures` | 電気的に大規模なアンテナ構造 (反射体、リフレクトアレイ、プラットフォーム搭載アンテナ、レーダー断面積) を設計・分析する。 |
| `matlab-analyze-em` | RF PCB の性能検証のために S パラメーター、挿入損失、電磁界、電流を計算する。 |
| `matlab-analyze-pcb-pdn` | PCB レイアウト上の PDN の DC 電圧・電流分布、IR ドロップ、設計規則チェックを分析する。 |
| `matlab-assemble-pcb-layout` | pcbComponent、シェイプ、ブール演算、フィード、多層スタックアップを使用してカスタム PCB 構造を構築する。 |
| `matlab-design-antenna` | MATLAB Antenna Toolbox を使用してアンテナ、アレイ、PCB アンテナを設計する。カタログ アンテナ設計、カスタム アンテナ構築、PCB アンテナ設計、有限・無限アレイ、AI 加速設計探索、最適化をカバーする。 |
| `matlab-design-pcb-coupler` | Wilkinson、branchline、ratrace、方向性結合器、コーポレート分配器、Rotman レンズを設計する。 |
| `matlab-design-pcb-filter` | hairpin、結合線路、combline、stub、SIW トポロジーを使用してバンドパス、ローパス、バンドストップ RF フィルターを設計する。 |
| `matlab-design-pcb-passive` | RF 回路用のスパイラル インダクター、インターデジタル キャパシタ、バラン、共振器、位相シフターを設計する。 |
| `matlab-design-pcb-transmission-line` | インピーダンス制御とクロストーク解析を使用してマイクロストリップ、ストリップライン、CPW、差動ペア伝送線路を設計する。 |
| `matlab-export-session-script` | 会話の MATLAB コードをクリーンで実行可能な .m スクリプトにエクスポートする。 |
| `matlab-integrate-antenna` | MATLAB Antenna Toolbox と RF Toolbox を使用してアンテナを RF システムに統合する。インピーダンス整合ネットワーク設計、実測アンテナ作成、RF 伝搬とサイト プランニング、SAR 推定をカバーする。 |
| `matlab-integrate-pcb-circuit` | PCB コンポーネントをカスケード接続し、集中定数素子を追加し、マルチコンポーネント RF 回路用の Touchstone ファイルをエクスポートする。 |
| `matlab-manage-pcb-material` | RF PCB シミュレーション用の誘電体基板、金属導体、多層スタックアップ、損失モデルを定義する。 |
| `matlab-model-ams-systems` | IC データシートまたはシステム仕様から Mixed-Signal Blockset を使用して PLL 周波数シンセサイザーをモデル化する。パラメーターを抽出し、アーキテクチャを選択し、Simulink モデルを組み立て、ループ フィルターを設計し、位相ノイズを検証する。 |
| `matlab-model-rf` | RF Toolbox と RF Blockset を使用して MATLAB で RF システム (S パラメーター I/O から完全な Circuit Envelope 時間領域シミュレーションまで) を設計、分析、シミュレーションする。 |
| `matlab-model-serdes-systems` | MATLAB SerDes Toolbox を使用して Serializer/Deserializer (SerDes) システム (シリアルおよびパラレル リンク) をモデル化、シミュレーション、最適化する。 |
| `matlab-model-via` | 高速 PCB レイヤー遷移用にパッド、アンチパッド、グランド リターン ビアを含むビアをモデル化する。 |
| `matlab-optimize-pcb-design` | patternsearch と surrogateopt を使用して帯域幅、リターン ロス、または面積に対して RF PCB コンポーネントの寸法を最適化する。 |
| `matlab-read-pcb-layout` | Gerber、ODB++、Allegro .brd ファイルをインポートし、ネット、レイヤー、シェイプ、スタックアップを検査する。 |
| `matlab-write-pcb-layout` | PCB 製造用に pcbComponent デザインを Gerber ファイルにエクスポートする。 |

### ロボティクスおよび自律システム ([`robotics-and-autonomous-systems`](../../skills-catalog/robotics-and-autonomous-systems/))

MATLAB、Navigation Toolbox&trade;、UAV Toolbox&trade;、Robotics System Toolbox&trade; をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-compute-gnss-position` | rinexread、gnssmeasurements、receiverposition、gnssoptions を使用して RINEX v3 データからマルチコンステレーション の GPS または GNSS 測位を計算する。 |
| `matlab-connect-mavlink` | MATLAB と PX4 または ArduPilot フライト コントローラー間の MAVLink 接続を確立する。 |
| `matlab-create-uav-scenario` | 地形、建物、センサー搭載プラットフォーム、3D 可視化を含む UAV シナリオを作成およびシミュレーションする。 |
| `matlab-fuse-inertial-sensors` | センサー構成を分析し、MATLAB Navigation Toolbox で慣性フュージョン フィルターを作成する。 |
| `matlab-model-robot-kinematics` | マニピュレーター モデルを構築し、MATLAB で運動学的な解を検証する。 |
| `matlab-plan-robot-motion` | 衝突を回避するマニピュレーター動作を計画し、時間パラメーター化された軌道を生成する。 |

### 信号処理 ([`signal-processing`](../../skills-catalog/signal-processing/))

MATLAB、Simulink、Audio Toolbox&trade;、DSP HDL Toolbox&trade;、DSP System Toolbox&trade;、Fixed-Point Designer、HDL Coder&trade;、Signal Processing Toolbox、Wavelet Toolbox&trade; をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-analyze-spectrum` | ノンパラメトリック推定量とパラメトリック推定量を使用して信号スペクトルを分析する。 |
| `matlab-analyze-time-frequency-content` | CWT、STFT、シンクロスクイージング、ウェーブレット コヒーレンスを使用して時間-周波数成分を分析する。 |
| `matlab-configure-scope-object` | スコープ関連の Simulink ブロックまたは MATLAB オブジェクトのプロパティを構成する。 |
| `matlab-design-adaptive-filter` | System objects を使用して適応フィルターを設計・実装する。 |
| `matlab-design-digital-filter` | MATLAB でデジタル フィルターを設計・検証する。 |
| `matlab-design-dsphdl-ddc` | dsphdl System objects を使用して HDL に最適化されたデジタル ダウン コンバーターを設計する。 |
| `matlab-extract-signal-features` | 1 次元信号からフレームごとの時間、周波数、時間-周波数特徴量を抽出する。 |
| `matlab-play-record-audio` | audiostreamer を使用して MATLAB でオーディオを再生・録音する。 |
| `matlab-prepare-signal-data` | 生信号の前処理 (ギャップ補間、トレンド除去、外れ値除去、ノイズ除去、リサンプリング/アライメント) を行い、ML トレーニング用の signalDatastore パイプライン (ラベル付け、層化分割、フレーミング、並列読み込み、trainnet への引き渡し) を構築する。 |
| `matlab-process-streaming-audio` | Audio Toolbox ストリーミング オブジェクトを使用してリアルタイム オーディオ処理チェーンを設計・実行する。 |
| `matlab-write-audio-plugin` | validateAudioPlugin と generateAudioPlugin を使用して VST/AU にコンパイルできる Audio Toolbox プラグインを作成する。 |

### テストと計測 ([`test-and-measurement`](../../skills-catalog/test-and-measurement/))

MATLAB、Data Acquisition Toolbox&trade;、Image Acquisition Toolbox&trade;、Image Processing Toolbox、Industrial Communication Toolbox&trade;、Vehicle Network Toolbox&trade;、MATLAB Support Package for Arduino Hardware&trade; をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-build-industrial-hmi` | ISA-101 規約に従って MATLAB で産業グレードの SCADA/HMI ダッシュボードを構築する。matlab-build-app が使用可能な場合はシリアル化を matlab-build-app に委譲して実際の App Designer アプリ (.mlapp) を生成し、そうでない場合はプログラムによる .m アプリにフォールバックする。 |
| `matlab-call-nidaqmx` | NI-DAQmx C 関数を正しい MATLAB calldaqlib 呼び出しに変換する。 |
| `matlab-connect-arduino` | USB 経由で MATLAB から Arduino&reg; ボードを検出、構成、接続する。 |
| `matlab-connect-bluetooth-low-energy-device` | MATLAB から Bluetooth Low Energy 周辺デバイスを検出・接続する。 |
| `matlab-create-custom-arduino-library` | MATLAB からサポートされていないセンサーや周辺機器にアクセスするためのカスタム Arduino アドオン ライブラリを作成する。 |
| `matlab-discover-hardware` | ヘルパー関数を使用して MATLAB でサポートされているハードウェア デバイスを検出、検査、セットアップする。 |
| `matlab-enhance-camera-image` | Image Acquisition Toolbox 経由で接続されたカメラの画像品質を診断・改善する。 |
| `matlab-find-pi-assets` | piclient と afclient を使用して PI Data Archive タグと Asset Framework 要素を検索・クエリする。 |
| `matlab-import-export-vehicle-data` | ログ ファイル (ASC、BLF、MDF、DAT、TXT) 車両ネットワーク データをインポートおよびデコードし、ログ ファイルにエクスポートする。ポリモーフィックな戻り値型の正しい処理、CAN/CAN FD/LIN デコード パイプライン、MDF/BLF 書き込みワークフローを含む。 |
| `matlab-modernize-daq` | レガシのセッション ベース Data Acquisition Toolbox コードを最新の DataAcquisition インターフェイスに移行する。 |
| `matlab-use-cameras` | Image Acquisition Toolbox videoinput インターフェイスを使用してカメラに接続し画像を取得する。 |
| `matlab-use-opcua-client` | OPC UA サーバーを検出し、セキュアな MATLAB クライアント接続を作成して、サーバー ノードをブラウズし、ノード階層を移動する。 |
| `matlab-use-vehicle-network` | すべてのサポート ハードウェア ベンダーにわたって Vehicle Network Toolbox を使用して MATLAB で CAN/CAN FD 車両ネットワーク通信をセットアップ、トラブルシューティング、分析する。 |

### 無線通信 ([`wireless-communications`](../../skills-catalog/wireless-communications/))

MATLAB、5G Toolbox&trade;、Bluetooth&reg; Toolbox&trade;、Communications Toolbox&trade;、Satellite Communications Toolbox&trade;、Wireless Network Toolbox&trade;、Wireless Testbench&trade;、WLAN Toolbox&trade;、Wireless Testbench Support Package for NI USRP Radios&trade; をサポート

| スキル | スキルがエージェントに提供する機能 |
|-------|---------------------------|
| `matlab-add-awgn` | 加法性ホワイト ガウス ノイズ (AWGN) を追加し、通信シミュレーション用に SNR、Eb/No、Es/No、サブキャリアごとの SNR 間で変換する。 |
| `matlab-design-ofdm-system` | ofdmmod/ofdmdemod を使用してカスタム OFDM システムを設計・シミュレーションする。フェージング チャネル構成、等化、同期 (タイミング/CFO)、LDPC 符号化、SNR ハンドリング、サブキャリア割り当て、パイロット ベースのチャネル推定を含む。 |
| `matlab-generate-5g-waveform` | 3GPP 準拠の 5G NR ダウンリンクおよびアップリンク ベースバンド波形を生成する。 |
| `matlab-generate-ble-waveform` | Bluetooth Low Energy PHY 波形を生成・分析する。 |
| `matlab-generate-gnss-waveform` | Satellite Communications Toolbox を使用して、物理的に現実的なチャネル劣化要因またはユーザー指定のチャネル劣化要因を含む GNSS ベースバンド波形 (GPS, Galileo, NavIC) を生成する。 |
| `matlab-generate-wlan-waveform` | IEEE 802.11 準拠の WLAN 波形を生成する。 |
| `matlab-set-up-usrp-radio` | Wireless Testbench で使用するための NI USRP ラジオをセットアップ・検証する。 |
| `matlab-simulate-bluetooth-network` | BLE、Classic BR/EDR、LE Audio を含む Bluetooth システム レベル ネットワークをシミュレーションする。 |
| `matlab-simulate-wireless-network` | wirelessNetworkSimulator を使用して無線ネットワーク シミュレーションをセットアップ・実行する。 |
| `matlab-transmit-capture-usrp` | NI USRP ラジオと Wireless Testbench を使用して RF 波形を送信・キャプチャする。 |

<!-- END SKILLS -->

## スキルのインストール方法

これらのスキルのインストール方法の詳細については、
[MATLAB Agentic Toolkit のインストール](../README.ja.md#matlab-agentic-toolkit-のインストール) を参照してください。

----

Copyright 2026 The MathWorks, Inc.

----
