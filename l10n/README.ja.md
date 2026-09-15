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
  日本語 •
  <a href="README.ko.md">한국어</a> •
  <a href="README.zh-cn.md">简体中文</a>
</p>

[![Latest Release](https://img.shields.io/github/v/release/matlab/matlab-agentic-toolkit?cacheSeconds=1800)](https://github.com/matlab/matlab-agentic-toolkit/releases/latest)
[![Release Date](https://img.shields.io/github/release-date/matlab/matlab-agentic-toolkit?cacheSeconds=1800)](https://github.com/matlab/matlab-agentic-toolkit/releases/latest)

MATLAB&reg; Agentic Toolkit を使用すると、AI エージェントに MATLAB およびそのツールボックスで効率的に作業するための知識やコンテキストを提供し、AI エージェントを MATLAB と連携させることができます。このツールキットを使用すると、エージェントから信頼性の高い MATLAB の機能を利用できるようになります。このツールキットは、AI コーディング エージェントが存在しないツールボックス関数を生成したり、新機能を見落としたり、MATLAB の経験豊富なユーザーであれば省略するような余分な手順に時間を費やしたりすることを防ぎます。

このツールキットでは以下のことができます。

- AI エージェントを MATLAB に接続する。このツールキットは [MATLAB MCP Server](https://github.com/matlab/matlab-mcp-server) を自動的にインストールすることでこれを実現します。その後、エージェントを使用して MATLAB らしいコードの作成、テストの生成と実行、エラーの診断、アプリの作成などを行うことができます。

- スキルと呼ばれる厳選された専門知識をエージェントに提供する。これらのスキルは MATLAB のワークフロー、規約、ベスト プラクティスに関する知識をエージェントに提供するとともに、トークン消費を最小限に抑えます。

> [!メモ]
> AI エージェントを Simulink&reg; でのみ使用する場合は、[Simulink Agentic Toolkit](https://github.com/matlab/simulink-agentic-toolkit) をインストールしてください。両方のツールキットをインストールする場合は、[Agentic Toolkit Installer](#matlab-agentic-toolkit-のインストール) を使用してください。


## 要件

* MATLAB R2021a 以降
* MCP サーバーとスキルをサポートする AI コーディング エージェント。サポートされているエージェントは自動的に設定されます。それ以外の場合は、エージェントのドキュメントを参照して MCP サーバーを手動で構成し、スキルをインストールしてください。サポートされているエージェントは以下のとおりです。
    - Claude Code
    - GitHub&reg; Copilot
    - OpenAI&reg; Codex
    - Gemini&trade; CLI
    - Amp

---
## MATLAB Agentic Toolkit の使用を開始する

以下の手順では、MATLAB Agentic Toolkit を使用して MATLAB MCP Server をインストールし、エージェントにスキルを追加する方法を示します。

> メモ: ローカル ファイルからのインストール、オフライン環境でのインストール、このツールキットの設定オプション、プラットフォーム固有の注意事項、検証手順、トラブルシューティング、インストーラーを使用しない手動セットアップについては、[Configuration and Troubleshooting](../Configuration_and_Troubleshooting.md) を参照してください。MCP サーバーが既にインストールされていてスキルの追加のみが必要な場合は、[Adding Skills Only](../Configuration_and_Troubleshooting.md#adding-skills-only) を参照してください。

### MATLAB Agentic Toolkit のインストール

以下の手順に従って MATLAB Agentic Toolkit をセットアップしてください。

1. インストーラーをダウンロードするには、[agenticToolkitInstaller.mltbx](https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx) をクリックします。
2. ダウンロードしたファイルを MATLAB で開いて、インストーラー アドオンをインストールします。
3. MATLAB で以下のコマンドを実行します。

```matlab
setupAgenticToolkit("install")
```

4. 作業に関連するスキル グループのみをインストールします。これにより、エージェントが適切なスキルを確実に呼び出せるようになります。後でスキル グループを追加するには、インストーラーを再実行します。
5. 既定では、エージェントを呼び出すと新しい MATLAB セッションが作成されます。エージェントを既存の MATLAB セッションに接続するには、MATLAB コマンド ウィンドウで次のコマンドを実行します。

```
shareMATLABSession()
```

複数の MATLAB セッションを実行している場合、エージェントは最後にこのコマンドを実行した MATLAB セッションに接続します。

または、このコマンドを MATLAB の [startup スクリプト](https://www.mathworks.com/help/matlab/ref/startup.html) に追加することもできます。


### 検証
エージェントに以下のように質問します。

```
What version of MATLAB is running? List the installed toolboxes.
```

### MCP ツールを使用した MATLAB コードの実行とテスト
MATLAB Agentic Toolkit のインストール後、エージェントは MATLAB MCP Server が提供する以下のツールを使用できます。

| エージェントに依頼できるタスク | エージェントが使用するツール |
|------|------------------------|
| MATLAB コードを実行してコマンド ウィンドウの出力を返す | `evaluate_matlab_code` |
| MATLAB プログラムを実行する | `run_matlab_file` |
| `runtests` で構造化された結果のテストを実行する | `run_matlab_test_file`|
| コード アナライザーによる静的コード解析 | `check_matlab_code` |
| インストール済みの MATLAB バージョンとツールボックスを一覧表示する | `detect_matlab_toolboxes` |

サーバーは `matlab_coding_guidelines` (コーディング規約) と `plain_text_live_code_guidelines` (ライブ スクリプトの書式ルール) の 2 つの MCP リソースも提供します。これらのリソースは、エージェントが必要に応じて参照できるリファレンス情報を提供します。

### エージェント スキルを使用した MATLAB ワークフローの実行
MATLAB Agentic Toolkit のインストール後、エージェントは MathWorks&reg; が厳選したスキルを使用できます。最良の結果を得るには、作業に関連するスキル グループのみをインストールしてください。読み込まれるスキルが少ないほど、エージェントはスキルをより確実に呼び出せるようになります。特定のスキルを名前で手動で呼び出すこともできます (例: Claude Code の `/matlab-write-tests`)。これにより、そのスキルが確実に読み込まれます。すべてのスキルの詳細については、[スキル カタログ](skills-catalog/README.ja.md) を参照してください。スキル グループには以下が含まれます。

<!-- BEGIN SKILLS -->
#### MATLAB スキル

| スキル グループ | 説明 |
|-------------|-------------|
| [**MATLAB 基本機能**](skills-catalog/README.ja.md#matlab-基本機能-matlab-core) | MATLAB コードとインストールの作成、デバッグ、テスト、レビュー、管理 |
| [**MATLAB アプリ作成**](skills-catalog/README.ja.md#matlab-アプリ作成-matlab-app-building) | UI コンポーネント、レイアウト、コールバック、Web 統合を使用して MATLAB アプリをプログラムで作成 |
| [**MATLAB データ インポートと解析**](skills-catalog/README.ja.md#matlab-データ-インポートと解析-matlab-data-import-and-analysis) | table、timetable、フィルタリング、集計、時系列演算を使用した MATLAB でのデータのインポート、エクスポート、解析 |
| [**MATLAB 環境と設定**](skills-catalog/README.ja.md#matlab-環境と設定-matlab-environment-and-settings) | リリース間の MATLAB 設定の差分比較とスタートアップ スクリプトの正しい設定パスへの移行 |
| [**MATLAB 外部言語インターフェイス**](skills-catalog/README.ja.md#matlab-外部言語インターフェイス-matlab-external-language-interfaces) | MATLAB から Python&reg; ライブラリを呼び出し、MEX ファイルをインターリーブされた複素数 API にアップグレード |
| [**MATLAB プログラミング**](skills-catalog/README.ja.md#matlab-プログラミング-matlab-programming) | 入力検証を備えた堅牢な MATLAB 関数の記述 |
| [**MATLAB ソフトウェア開発**](skills-catalog/README.ja.md#matlab-ソフトウェア開発-matlab-software-development) | レガシ コードの最新化、パフォーマンスとメモリの最適化、ドキュメント作成とツールボックスの作成、プロジェクトの作成、ビルド プランの作成 |

#### ツールボックス スキル

| スキル グループ | サポート対象製品 |
|-------------|--------------------|
| [**航空宇宙関連**](skills-catalog/README.ja.md#航空宇宙関連-aerospace) | MATLAB、Aerospace Toolbox&trade; |
| [**AI および統計**](skills-catalog/README.ja.md#ai-および統計-ai-and-statistics) | MATLAB、Simulink、Curve Fitting Toolbox&trade;、Deep Learning Toolbox&trade;、Embedded Coder&trade;、Fixed-Point Designer&trade;、MATLAB Coder&trade;、MATLAB Compiler SDK&trade;、MATLAB Report Generator&trade;、Optimization Toolbox&trade;、Parallel Computing Toolbox&trade;、Statistics and Machine Learning Toolbox&trade;、Deep Learning Toolbox Converter for ONNX Model Format&trade;、Deep Learning Toolbox Converter for PyTorch Models&trade;、Deep Learning Toolbox Converter for TensorFlow Models&trade; |
| [**自動車関連**](skills-catalog/README.ja.md#自動車関連-automotive) | MATLAB、Simulink、Automated Driving Toolbox&trade;、Computer Vision Toolbox&trade;、RoadRunner、RoadRunner Scenario、RoadRunner Scene Builder、Sensor Fusion and Tracking Toolbox&trade;、Automated Driving Toolbox Interface for Eclipse SUMO Traffic Simulator&trade;、Scenario Builder for Automated Driving Toolbox&trade; |
| [**クラウド ソリューション**](skills-catalog/README.ja.md#クラウド-ソリューション-cloud-solutions) | MATLAB、MATLAB Drive&trade; |
| [**コード生成**](skills-catalog/README.ja.md#コード生成-code-generation) | MATLAB、Embedded Coder、Fixed-Point Designer、GPU Coder&trade;、MATLAB Coder、MATLAB Test&trade;、Parallel Computing Toolbox、MATLAB Coder Support Package for PyTorch and LiteRT Models&trade; |
| [**情報生命科学**](skills-catalog/README.ja.md#情報生命科学-computational-biology) | MATLAB、SimBiology&trade;、Statistics and Machine Learning Toolbox |
| [**金融工学**](skills-catalog/README.ja.md#金融工学-computational-finance) | MATLAB、Datafeed Toolbox&trade;、Financial Instruments Toolbox&trade;、Financial Toolbox&trade;、Spreadsheet Link&trade; |
| [**制御システム**](skills-catalog/README.ja.md#制御システム-control-systems) | MATLAB、Control System Toolbox&trade;、Predictive Maintenance Toolbox&trade;、Signal Processing Toolbox&trade;、Statistics and Machine Learning Toolbox、System Identification Toolbox&trade; |
| [**イメージ処理とコンピューター ビジョン**](skills-catalog/README.ja.md#イメージ処理とコンピューター-ビジョン-image-processing-and-computer-vision) | MATLAB、Computer Vision Toolbox、Deep Learning Toolbox、Image Processing Toolbox&trade;、Lidar Toolbox&trade;、Medical Imaging Toolbox&trade;、Optical Design and Simulation Library for Image Processing Toolbox&trade; |
| [**数学および最適化**](skills-catalog/README.ja.md#数学および最適化-math-and-optimization) | MATLAB、Optimization Toolbox、Partial Differential Equation Toolbox&trade;、Symbolic Math Toolbox&trade; |
| [**並列計算**](skills-catalog/README.ja.md#並列計算-parallel-computing) | MATLAB、Parallel Computing Toolbox、MATLAB Parallel Server&trade; |
| [**レーダー**](skills-catalog/README.ja.md#レーダー-radar) | MATLAB、Mapping Toolbox&trade;、Phased Array System Toolbox&trade;、Radar Toolbox&trade;、Sensor Fusion and Tracking Toolbox、Signal Processing Toolbox |
| [**レポートとデータベース アクセス**](skills-catalog/README.ja.md#レポートとデータベース-アクセス-reporting-and-database-access) | MATLAB、Database Toolbox&trade;、MATLAB Report Generator、Parallel Computing Toolbox、Simulink Report Generator&trade; |
| [**RF およびミックスド シグナル**](skills-catalog/README.ja.md#rf-およびミックスド-シグナル-rf-and-mixed-signal) | MATLAB、Simulink、Antenna Toolbox&trade;、Mixed-Signal Blockset&trade;、RF Blockset&trade;、RF PCB Toolbox&trade;、RF Toolbox&trade;、SerDes Toolbox&trade;、Signal Integrity Toolbox、Signal Processing Toolbox、Statistics and Machine Learning Toolbox |
| [**ロボティクスおよび自律システム**](skills-catalog/README.ja.md#ロボティクスおよび自律システム-robotics-and-autonomous-systems) | MATLAB、Navigation Toolbox&trade;、UAV Toolbox&trade;、Robotics System Toolbox&trade; |
| [**信号処理**](skills-catalog/README.ja.md#信号処理-signal-processing) | MATLAB、Simulink、Audio Toolbox&trade;、DSP HDL Toolbox&trade;、DSP System Toolbox&trade;、Fixed-Point Designer、HDL Coder&trade;、Signal Processing Toolbox、Wavelet Toolbox&trade; |
| [**テストと計測**](skills-catalog/README.ja.md#テストと計測-test-and-measurement) | MATLAB、Data Acquisition Toolbox&trade;、Image Acquisition Toolbox&trade;、Image Processing Toolbox、Industrial Communication Toolbox&trade;、Vehicle Network Toolbox&trade;、MATLAB Support Package for Arduino Hardware&trade; |
| [**無線通信**](skills-catalog/README.ja.md#無線通信-wireless-communications) | MATLAB、5G Toolbox&trade;、Bluetooth&reg; Toolbox&trade;、Communications Toolbox&trade;、Satellite Communications Toolbox&trade;、Wireless Network Toolbox&trade;、Wireless Testbench&trade;、WLAN Toolbox&trade;、Wireless Testbench Support Package for NI USRP Radios&trade; |
<!-- END SKILLS -->
---
## MATLAB Agentic Toolkit の更新

ツールキットを更新するには、[agenticToolkitInstaller.mltbx](https://github.com/matlab/simulink-agentic-toolkit/releases/latest/download/agenticToolkitInstaller.mltbx) をクリックして最新のインストーラー アドオンをダウンロードします。ダウンロードしたファイルを MATLAB で開き、MATLAB で次のコマンドを実行します。

```matlab
setupAgenticToolkit("update")
```

これにより、MATLAB および Simulink Agentic Toolkit の スキル、設定、MCP サーバー バイナリが更新されます。

---
## セキュリティに関する考慮事項
MATLAB Agentic Toolkit および MATLAB MCP Server を使用する場合、すべてのツール呼び出しを実行前に十分にレビューおよび検証する必要があります。重要なアクションについては常に人間による確認を介在させ、呼び出しが期待どおりに動作することを十分に確認してから実行してください。詳細については、[User Interaction Model (MCP)](https://modelcontextprotocol.io/specification/latest/server/tools#user-interaction-model) および [Security Considerations (MCP)](https://modelcontextprotocol.io/specification/latest/server/tools#security-considerations) を参照してください。

---
## データ収集

MATLAB MCP Server は既定で匿名化された使用状況データを収集します。詳細については、MCP サーバーのドキュメントの [データ収集](https://github.com/matlab/matlab-mcp-server/blob/main/l10n/README.ja.md#%E3%83%87%E3%83%BC%E3%82%BF%E5%8F%8E%E9%9B%86) を参照してください。オプトアウトするには、[Disable Data Collection](../Configuration_and_Troubleshooting.md#disable-data-collection) を参照してください。

---
## ライセンスと使用条件
ライセンスは、この GitHub リポジトリの [LICENSE.md](../LICENSE.md) ファイルで確認できます。

MCP サーバーは、MathWorks Software License Agreement に従って MATLAB での使用のみが許可されており、複数のユーザーで共有することはできません。共有または集中管理型のサーバー使用をサポートする必要がある場合は、MathWorks にお問い合わせください。

---
## サポートと貢献
MathWorks は、このリポジトリの使用とフィードバックの提供をお勧めしています。このリポジトリではプル リクエストは有効になっていません。テクニカル サポートのリクエストまたは機能強化リクエストの送信は、[GitHub issue を作成する](https://github.com/matlab/matlab-agentic-toolkit/issues)か、[テクニカル サポートにお問い合わせ](https://www.mathworks.com/support/contact_us.html)ください。


----

Copyright 2026 The MathWorks, Inc.

----
