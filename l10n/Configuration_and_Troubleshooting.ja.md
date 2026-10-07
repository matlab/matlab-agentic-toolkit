<!--
Source English Markdown:
- File: ./Configuration_and_Troubleshooting.md
- Branch: main
- Commit: 645cf259dedf8b012f89fdb7006ad7c1afa33e3e
-->

# 構成とトラブルシューティング

<p align="center">
  <a href="../Configuration_and_Troubleshooting.md">English</a> •
  <a href="Configuration_and_Troubleshooting.es.md">Español</a> •
  日本語 •
  <a href="Configuration_and_Troubleshooting.ko.md">한국어</a> •
  <a href="Configuration_and_Troubleshooting.zh-cn.md">简体中文</a>
</p>

このページでは、MATLAB&reg; Agentic Toolkit を構成する方法について説明します。MATLAB Agentic Toolkit の概要については、[README](README.ja.md) を参照してください。

## 要件

- MATLAB R2021a 以降
- MCP サーバーとスキルをサポートする AI コーディング エージェント。サポートされているエージェントは自動的に構成されます。それ以外の場合は、エージェントのドキュメントを参照して、MCP サーバーを手動で構成し、スキルをインストールしてください。サポートされているエージェントには以下が含まれます。
  - Claude Code
  - GitHub&reg; Copilot
  - OpenAI&reg; Codex
  - Gemini&trade; CLI
  - Amp

---

## ローカル ファイルからのインストール (オフライン コンピューター)

オフライン環境またはエアギャップ環境で MATLAB Agentic Toolkit をインストールするには、まずインターネットに接続されたコンピューターで次のコンポーネントをダウンロードし、対象のマシンまたは共有場所に転送します。

| コンポーネント | 入手先 |
|----------|----------------|
| MCP サーバー バイナリ | [MATLAB MCP Server latest release](https://github.com/matlab/matlab-mcp-server/releases/latest) — お使いのプラットフォーム用のバイナリ (例: `matlab-mcp-server-macos-arm64`、`matlab-mcp-server-windows-x64.exe`) をダウンロードします。 |
| MCP サーバー ツールボックス | [MATLAB MCP Server latest release](https://github.com/matlab/matlab-mcp-server/releases/latest) — `MATLABMCPServerToolbox.mltbx` をダウンロードします。 |
| Agentic Toolkit インストーラー | [Simulink Agentic Toolkit latest release](https://github.com/matlab/simulink-agentic-toolkit/releases/latest) — `agenticToolkitInstaller.mltbx` をダウンロードします。 |
| MATLAB Agentic Toolkit | [GitHub](https://github.com/matlab/matlab-agentic-toolkit) からクローンまたはダウンロードします。 |
| Simulink Agentic Toolkit | [GitHub](https://github.com/matlab/simulink-agentic-toolkit) からクローンまたはダウンロードします。Simulink Agentic Toolkit をインストールする場合にのみ必要です。|

これらのコンポーネントをダウンロードした後、MATLAB で `agenticToolkitInstaller.mltbx` を開いてインストーラー アドオンをインストールします。
MATLAB のコマンド ウィンドウで、以下の名前と値の引数を指定して `setupAgenticToolkit` コマンドを実行します。

| 引数 | 値 |
|----------|-----------------|
| `MCPServerLocation` | ダウンロードした MCP サーバー バイナリへのパス |
| `MCPToolboxLocation` | ダウンロードした MATLAB ツールボックス (`.mltbx`) へのパス |
| `MATLABAgenticToolkitLocation` | MATLAB Agentic Toolkit リポジトリ クローンへのパス |
| `SimulinkAgenticToolkitLocation` | Simulink Agentic Toolkit リポジトリ クローンへのパス |

インストーラーは、ローカルで提供されないコンポーネントをダウンロードします。インターネット アクセスを禁止し、コンポーネントが利用できない場合にエラーを報告するには、`Offline=true` を設定します。たとえば、ローカル ファイルから MATLAB Agentic Toolkit をインストールするには次のコマンドを使用します。

```matlab
setupAgenticToolkit("install", Offline=true,  ...
    MCPServerLocation="/shared/agentic-toolkits/bin/matlab-mcp-server-linux-x64", ...
    MCPToolboxLocation="/shared/agentic-toolkits/toolboxes/MATLABMCPServerToolbox.mltbx", ...
    MATLABAgenticToolkitLocation="/shared/agentic-toolkits/matlab-agentic-toolkit")
```

---

## エージェントを使用した MATLAB のインストール

MATLAB がインストールされていない場合は、以下の手順で AI エージェントを使用して MATLAB をインストールできます。
1) [スキルのみ追加](#adding-skills-only)の手順で MATLAB Agentic Toolkit スキルをインストールします。
2) エージェントに `matlab-install-products` スキルを使用して MATLAB をインストールするよう指示します。

MATLAB のインストール後、[Agentic Toolkit インストーラー](README.ja.md#matlab-agentic-toolkit-のインストール) の手順に従って MATLAB MCP Server を自動的にインストールするか、MATLAB MCP Server を手動でインストールして構成することにより、MATLAB Agentic Toolkit のセットアップを完了できます。

---

## MCP サーバーのインストールと構成

自動セットアップを使用せずに MCP サーバーを手動でインストールおよび構成するには、[MATLAB MCP Server](https://github.com/matlab/matlab-mcp-core-server) GitHub リポジトリの手順を参照してください。MCP サーバーをインストールした後、エージェントの MCP 構成でインストールされたバイナリを指定します。構成ファイルの場所については以下の表を参照するか、エージェントのドキュメントを参照してください。

| プラットフォーム | MCP 構成 | プラットフォーム固有の注意事項 |
|----------|------------------|-------------------|
| Claude Code | `~/.claude.json` | 構成には `claude mcp add` を使用します。 |
| GitHub Copilot | VS Code ユーザー プロファイル `mcp.json` | セットアップ完了後に VS Code を再読み込みします。 |
| OpenAI Codex | `~/.codex/config.toml` | セットアップ後、`~/.codex/config.toml` の `[mcp_servers.matlab]` セクションで 2 つの設定を調整できます。1) テスト スイートやシミュレーションのような長時間の MATLAB 操作に対してツール タイムアウトを延長するために、`tool_timeout_sec = 600` を設定します。非常に長時間実行するタスクの場合はさらに増やしてください。2) Codex は既定で MCP サーバーのサブプロセスから環境変数を除去するため、Windows&reg; で Simulink&reg; を動作させるには `env_vars = ['WINDIR']` を設定します。 |
| Gemini CLI | `~/.gemini/settings.json` | セットアップ後に新しい Gemini セッションを開始します。 |
| Amp | `~/.config/amp/settings.json` | MCP サーバーをブロックする `amp.mcpPermissions` ルールがある場合は、MATLAB サーバーに対する許可ルールを追加します。 |

---

## データ収集の無効化

MATLAB MCP Server は、サーバーの使用状況について完全に匿名化された情報を収集し、MathWorks&reg; に送信します。このデータ収集は MathWorks の製品改善に役立ち、既定でオンになっています。データ収集をオプトアウトするには、MATLAB で次のコマンドを実行して、`DisableTelemetry` オプションを `true` に設定してツールキットを構成します。

```matlab
setupAgenticToolkit("configure", DisableTelemetry=true)
```

このコマンドは、構成されたすべてのエージェントに対してデータ収集をオプトアウトします。この設定は、`setupAgenticToolkit("update")` でツールキットを新しいバージョンに更新しても保持されます。`setupAgenticToolkit("configure")` を実行してエージェントに対してツールキットを再構成する場合、データ収集を無効のままにするには、再度 `DisableTelemetry=true` を含めます。

---

<a id="adding-skills-only"></a>
## スキルのみの追加

MATLAB MCP Server が既にある場合は、スキルのみが必要です。スキルは `skills-catalog/` の下のフォルダー (スキル グループと呼ばれる) にまとめられています。`matlab-core` スキル グループはインストールする必要があります。追加のドメインの専門知識のために、他の特定のスキル グループを個別にインストールできます。エージェントがスキルを確実にトリガーできるように、必要なスキルのみをインストールしてください。ワークフローで特定のスキルを確実に読み込むには、その名前を使用して手動でスキルをトリガーすることもできます。

スキル グループとスキルの詳細については、[`skills-catalog/` README](skills-catalog/README.ja.md) を参照してください。

### Claude Code

各スキル グループは Claude Code プラグインとして提供されます。スキル グループを追加するには、最初にマーケットプレイスを追加してから、`matlab-core` スキル グループをインストールします。

```bash
claude plugin marketplace add "https://github.com/matlab/matlab-agentic-toolkit"
claude plugin install matlab-core@matlab-agentic-toolkit
```

`matlab-core` スキル グループをインストールした後、グループのディレクトリ名を使用して同じパターンで特定のスキル グループをインストールします。

```bash
claude plugin install <group-name>@matlab-agentic-toolkit
```

たとえば、信号処理と無線通信のスキルを追加するには次のようにします。

```bash
claude plugin install signal-processing@matlab-agentic-toolkit
claude plugin install wireless-communications@matlab-agentic-toolkit
```

プロンプトが表示されたら、使用するスコープ (プロジェクト単位、ユーザー単位、またはグローバル) を選択します。既存の MCP 構成は変更されません。


### GitHub Copilot、OpenAI Codex、Gemini CLI

他のほとんどの AI エージェントは、`~/.agents/skills/` からスキルを検出します。エージェントにスキルを追加するには、`~/.agents/skills/` フォルダーから個々のスキル グループへのシンボリック リンクをセットアップする必要があります。まず、ツールキットをクローンします。

```bash
git clone https://github.com/matlab/matlab-agentic-toolkit.git
```

ツールキットをクローンした後、必要な各グループに対してシンボリック リンクを作成します。`/path/to/matlab-agentic-toolkit` を実際のツールキット クローンのパスに置き換え、必要なグループを列挙します。たとえば、`matlab-core` と `signal-processing` をインストールするには、次のコマンドを使用します。

```bash
mkdir -p ~/.agents/skills
for group in matlab-core signal-processing; do
  for skill in /path/to/matlab-agentic-toolkit/skills-catalog/$group/*/; do
    ln -s "$skill" ~/.agents/skills/$(basename "$skill")
  done
done
```

または、Gemini の場合、ツールキットを Gemini CLI 拡張機能としてインストールすることでスキルを追加できます。
  ```bash
 gemini extensions install https://github.com/matlab/matlab-agentic-toolkit
  ```

### Amp

Amp は `~/.config/amp/settings.json` に記載されたパスからスキルを読み取ります。まず、ツールキットをクローンします。

```bash
git clone https://github.com/matlab/matlab-agentic-toolkit.git
```

ツールキットをクローンした後、必要な各グループの `skills-catalog/<group>` のパス エントリを追加します。

```json
{
  "amp.skills.path": [
    "/path/to/matlab-agentic-toolkit/skills-catalog/matlab-core",
    "/path/to/matlab-agentic-toolkit/skills-catalog/signal-processing"
  ]
}
```

---

## 検証

### スキルが読み込まれていることを確認する

エージェントの UI に読み込まれたスキルまたはプラグインが表示される場合 (例: Claude Code の `/skills` コマンド)、MATLAB Agentic Toolkit スキルがリストされていることを確認します。

### 試す

エージェントに次のように尋ねます。

```
実行中の MATLAB のバージョンを教えてください。インストールされているツールボックスを一覧表示してください。
```

エージェントは MCP を使用して `detect_matlab_toolboxes` を呼び出し、MATLAB のバージョンと利用可能なツールボックスを報告します。

### その他の例

```
信号の移動平均を計算する関数を作成し、そのユニット テストを生成してください。
```

```
myScript.m のコード品質上の問題をレビューし、改善案を提案してください。
```

```
サンプル データを使用した曲線近似を示すプレーンテキストのライブ スクリプトを作成してください。
```
---

## プロジェクト単位の構成

リポジトリ直下の [README](README.ja.md) の自動セットアップを使用して MATLAB Agentic Toolkit をインストールすると、ツールキットはグローバルに構成されます。開いているプロジェクトに関係なく、すべてのセッションで MATLAB ツールとスキルが利用できます。

MCP サーバーをプロジェクト レベルで構成することもできます。これにより、必要なプロジェクトにのみツールとスキルを利用できるようになります。構成をバージョン管理にコミットすると、リポジトリをクローンする誰もが (MCP サーバー バイナリがインストールされていれば) MATLAB 接続を自動的に取得できるので、チームにも役立ちます。

### テンプレート ファイル

[`templates/`](../templates/) ディレクトリには、各プラットフォームのスターター構成が含まれています。適切なテンプレートをプロジェクトのルート フォルダーにコピーし、パスを更新して、バージョン管理にコミットします。

| プラットフォーム | テンプレート | プロジェクト内の場所 |
|----------|----------|-----------------|
| GitHub Copilot | `templates/vscode-mcp.json` | `.vscode/mcp.json` |
| Amp | `templates/amp-settings.json` | `.amp/settings.json` |
| OpenAI Codex | `templates/codex-mcp.json` | プロジェクト ルートの `.codex/config.json` |

> **Claude Code** は、プロジェクト構成ファイルではなく、`claude plugin install` でスコープ (プロジェクト単位、ユーザー単位、またはグローバル) を選択して設定します。[スキルのみ追加](#adding-skills-only) を参照してください。

### 例: GitHub Copilot

```bash
mkdir -p .vscode
cp /path/to/matlab-agentic-toolkit/templates/vscode-mcp.json .vscode/mcp.json
```

その後、`.vscode/mcp.json` を編集して、プレースホルダー パスを実際の MCP サーバー バイナリ パスと MATLAB ルート パスに置き換えます。

> **メモ:** プロジェクト単位の構成には、MCP サーバー バイナリと MATLAB ルートへの絶対パスが含まれており、これらはマシンごとに異なります。チームが異なる OS プラットフォームやインストール場所を使用する場合は、プロジェクトの README で想定されるパスをドキュメント化することを検討してください。

---

## トラブルシューティング

| 問題 | 考えられる原因 | 修正方法 |
|---------|-------------|-----|
| セットアップで MATLAB が見つからない | 標準以外のインストール場所 | プロンプトが表示されたらパスを指定します。 |
| MCP サーバーのダウンロードに失敗する | ネットワーク/プロキシ/ファイアウォール | [GitHub のリリース](https://github.com/matlab/matlab-mcp-core-server/releases) から手動でダウンロードし、`~/.matlab/agentic-toolkits/bin/` に格納してセットアップを再実行します。 |
| macOS が MCP サーバー バイナリをブロックする | Gatekeeper の隔離 | セットアップが自動的に処理します。まだブロックされている場合 (MDM)、[システム設定] > [プライバシーとセキュリティ] > [このまま許可] に進みます。 |
| エージェントが MATLAB スキルを一覧表示しない | プラグインがインストールされていない、またはスキルがリンクされていない | セットアップを再実行します。Claude Code の場合は `claude plugin install matlab-core@matlab-agentic-toolkit` を試します。 |
| MCP ツールが接続に失敗する | MCP サーバー バイナリがないか、構成のパスが間違っている | セットアップを再実行して構成を再生成します。`~/.matlab/agentic-toolkits/bin/matlab-mcp-server --version` でバイナリの存在を確認します。|
| `evaluate_matlab_code` がエラーを返す | `--matlab-root` のパスが間違っている、ライセンスの問題、または MATLAB の起動失敗 | `<matlab-root>/bin/matlab -nodesktop -r "disp('ok'),quit"` で MATLAB を起動できることを確認します。ライセンスの状態を確認します。セットアップを再実行して MATLAB ルート パスを修正します。 |
| Codex のツール呼び出しがタイムアウトする | 既定のツール タイムアウトが MATLAB には短すぎる | `~/.codex/config.toml` の `[mcp_servers.matlab]` に `tool_timeout_sec = 600` (またはそれ以上) を追加します。 |
| Windows で Codex の Simulink が失敗する | `WINDIR` 環境変数がない | `~/.codex/config.toml` の `[mcp_servers.matlab]` に `env_vars = ['WINDIR']` を追加します。 |
| スキルが自動読み込みされない | インストールされているスキルが多すぎる | 以下の「[スキルが自動読み込みされない](#skills-not-auto-loading)」を参照してください。 |

---

<a id="skills-not-auto-loading"></a>
### スキルが自動読み込みされない

エージェントのコンテキストには制限があります。多くのスキル グループをインストールすると、一部のスキルが見落とされたり、コンテキストから除外されたりして、特定のタスクに対して正しいスキルがエージェントで自動的にトリガーされない場合があります。

#### 推奨される解決策

1. 必要なスキル グループのみインストールする: これが推奨される解決策です。MATLAB ベースのインストーラー (`setupAgenticToolkit("install")`) を使用して、作業に関連する特定のスキル グループを選択します。インストールされるスキルが少ないほど、エージェントはより確実に正しいスキルを識別してトリガーできます。

2. スキルを名前で手動でトリガーする: 必要なスキルがわかっている場合は、直接トリガーします。
   - Claude Code では、スラッシュ コマンド (例: `/matlab-write-tests`) を使用します。
   - 他のエージェントでは、「matlab-write-tests スキルを使用して...」のように明示的に指示します。

3. 使用しないスキル グループを削除する: エージェントベースのセットアップですべてのグループをインストールした場合は、必要ないものを削除します。
   - Claude Code: `claude plugin remove <group-name>@matlab-agentic-toolkit`。
   - Copilot、Codex、Gemini CLI: `~/.agents/skills/` から対応するシンボリック リンクを削除します。
   - Amp: `~/.config/amp/settings.json` の `amp.skills.path` からグループのパスを削除します。

多くのスキルがインストールされている場合のスキル検出と自動読み込みを改善するため、より堅牢な解決策を積極的に検討しています。

---

## サポートと貢献
MathWorks は、このリポジトリを使用してフィードバックを提供することを推奨しています。このリポジトリではプル リクエストは有効になっていません。技術サポートを依頼したり、機能拡張リクエストを送信したりするには、[GitHub Issue を作成](https://github.com/matlab/matlab-agentic-toolkit/issues)するか、[テクニカル サポートにお問い合わせ](https://www.mathworks.com/support/contact_us.html)ください。

----

Copyright 2026 The MathWorks, Inc.

----
