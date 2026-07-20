# MeetLog（商談録音・要約・ToDoアプリ）

個人利用専用・完全オンデバイスで動くiPhoneアプリ。仕様の全体像は [CLAUDE.md](./CLAUDE.md) を参照。

現在のステータス：**Phase 1（PoC）** ― 長時間録音＋オンデバイス文字起こし＋Foundation Modelsによる要約のプロトタイプ。

## 構成

```
project.yml                XcodeGenのプロジェクト定義（.xcodeprojはこれから生成する。コミットしない）
Sources/MeetLog/
  App/                      アプリ起点・4タブのルート
  Views/                    SwiftUI画面
  Services/                 録音・文字起こし・要約・ToDo/履歴ストア
  Models/                   RecordingSession・ChunkSummary・ToDoItem 等
.github/workflows/build.yml  GitHub ActionsでmacOSランナー上でのビルド確認
```

## Macを持っていない場合のビルド・実機インストール手順（無料構成）

本プロジェクトはXcode（macOS専用）が必須ですが、以下の構成でMacを一切購入・レンタルせずに完結できます。

1. **コードはこのリポジトリで編集**（Windows上で普通のテキスト編集）
2. **GitHub Actions（パブリックリポジトリ・無料枠）**が `xcodegen generate` → `xcodebuild` を実行し、コードが壊れていないかを確認
   - `.github/workflows/build.yml` は現状シミュレータ向けビルドの確認までを行う
   - 実機用のアーカイブ・署名・`.ipa` 書き出しは、Apple Developer関連の秘密情報をGitHub Secretsに登録した上で別ジョブとして追加する（現時点では未設定）
3. **AltStore / AltServer**（無料）で実機にインストール
   - AltServerはWindows上で動作し、無料のApple IDでiPhoneへ直接サイドロードできる
   - 7日ごとに同じWi-Fi上での自動リフレッシュが必要

この手順の詳細な設定（Apple ID登録、AltServerのペアリング、CIでの`.ipa`書き出しジョブ）は、実際にビルドが通るようになった後の次のステップとして行う。

## Macが使える場合

```
brew install xcodegen
xcodegen generate
open MeetLog.xcodeproj
```

## 現時点の実装範囲（Phase 1: PoC）

- 録音（カテゴリ選択・タイトル・長時間録音・AAC圧縮保存）
- 商談カテゴリの同意確認フロー
- オンデバイスストリーミング文字起こし（`SFSpeechRecognizer`、チャンク単位でリクエストを再生成）
- Foundation Modelsによる①区間要約 → ②累積要約（リファイン）→ ③最終要約
- ToDo候補の確認・登録、期限順一覧、完了即削除、期限超過24時間猶予
- 履歴一覧（**アプリ起動中のみ保持。ディスク永続化は未実装**）

## 既知の制約・次のステップ（実装時に検証すべき点）

- **チャンク分割**：現状は無音検出（VAD）ではなく固定4分間隔。仕様書§9-2で想定している自然な無音区切りへの置き換えが必要
- **Foundation Models framework のAPI**：比較的新しいAPIのため、導入するXcode/iOS SDKのバージョンに合わせて `SummarizerService.swift` のシグネチャを確認・調整すること
- **長時間録音時の文字起こし安定性**：数時間単位での`SFSpeechRecognizer`のリソース競合・精度を実機で検証する必要あり（CLAUDE.md記載の検証項目）
- **永続化**：履歴・ToDoは現状インメモリのみ。SwiftData等での永続化はPhase 3〜4で対応
- **48時間自動削除バッチ・通知**：モデル側にフィールド（`deletionDeadline`）は用意済みだが、実際のバックグラウンド削除処理・ローカル通知は未実装（Phase 4）
