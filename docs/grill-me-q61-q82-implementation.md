# Grill-Me Q61〜Q82 実装トレーサビリティ

この文書は、2026-08-27〜29のGrill-Meで確定した追加要求を、実装箇所と検証へ対応づける。

## 実装済み

| Q | 決定 | 主な実装 |
|---|---|---|
| Q61 | 嘘を作らないAI断り文・ガチャ | `ConversationAssistantService.swift`, `DeclineDraftSheet` |
| Q62 | 予定負荷から余白量を自動推定、少なめ/ふつう/多め | `MarginRecommendationEngine.swift`, Onboarding, My Margins, Settings |
| Q63 | Miraが最初から複数候補を提示 | `SchedulingRecommendationEngine.swift`, `SchedulingModeView` |
| Q64 | 朝/昼/夜、午前/午後、終日を標準。詳細時刻は任意 | `DurationBucket`, `SchedulingTimeBand`, `SchedulingModeView` |
| Q65 | 候補数は基本3、良候補に応じて2〜5 | `SchedulingRecommendationEngine.recommendedCount` |
| Q66 | ホームの雑入力1つ＋軽い会話継続 | `MiraQuickInputBar`, `MiraStore+Conversation` |
| Q67 | 案件単位で状態・会話を保持 | `ConversationCaseEntity`, `ConversationCaseState` |
| Q68 | LLMより先にHarness検索、高確度自動選択、手動指定あり | `CaseSearchEngine`, `ContextPickerSheet` |
| Q69 | 通常検索は過去を除外、手動で過去も検索 | `CaseSearchEngine`, Context Pickerのトグル |
| Q70 | 案件ピッカー内を進行中/検討中/確定予定で分類 | `ContextPickerSheet` |
| Q71 | 雑入力とボタンの両方から同じ日程調整モード | Home/Adjustmentの入口、`SchedulingModeView` |
| Q72 | AIが不足条件を仮入力し、推定チップを表示 | `ConversationAssistantService`, `RobustConversationInterpreter`, `SchedulingModeView` |
| Q73 | 確認画面を挟まず即カレンダー調整モード | `MiraStore.startSchedulingDraft` |
| Q74 | 全日の時間帯ボタンを表示し、推奨/通常/要確認を区別 | `SchedulingModeView` |
| Q75 | おすすめを初期選択、全解除ボタンあり | `SchedulingDraft.selectedRecommendationIDs`, `SchedulingModeView` |
| Q76 | 候補は時間帯＋所要時間で保持 | `CandidateSlotSnapshot` の粗い時間メタデータ |
| Q77 | 送信候補を仮押さえ、警告付きで重複利用可能 | Adjustment candidates / conflict engine |
| Q78 | 日付・時間帯だけでも確定予定へ昇格 | `confirmCandidate`, `CalendarItemSnapshot.exactTimeKnown` |
| Q79 | 会話全文を案件に保存、モデルには直近だけ渡す | `ConversationCaseEntity.turns`, Hybrid interpreter |
| Q80 | 自然言語変更は変更前→変更後プレビュー後に保存 | `ChangePreview`, `ChangePreviewSheet` |
| Q81 | LINE等の本文をそのまま貼って構造化 | `RobustConversationInterpreter`, universal input |
| Q82 | 裏で再計算、問題時だけ完成案を提示、変更は承認後 | `RebalanceEngine`, `RebalanceProposalSheet` |

## 共通原則

- AIは意図分類・情報抽出・文章生成を担当する。
- 検索、空き判定、重複、負荷、目標、候補順位、保存は決定論ロジックが担当する。
- 予定や候補を完全禁止せず、影響と代替案を示して最終判断を本人に残す。
- AIが利用できなくても、ルールベースと手動入口で中心機能を完遂できる。

## 検証

- `MiraTests/ConversationalSchedulingTests.swift`
  - 日本語の曖昧案件検索
  - 過去予定の明示検索
  - 2〜5件の候補ランキング
  - 粗い時間帯＋所要時間の保持
  - 余白強度による目標差
  - 貼り付け誘いの候補抽出
  - 嘘を作らない断り文
- `MiraUITests/GrillMeFlowUITests.swift`
  - 雑入力から日程調整モード
  - おすすめ初期選択と一括解除
  - 案件ピッカーと過去検索
  - 予定追加プレビュー
- `.github/workflows/grill-me-complete.yml`
  - Xcode 16.4でフォールバック経路を含むBuild/Unit/UI Test
  - Xcode 26でFoundation Models分岐を含むBuild
- `.github/workflows/screenshots.yml`
  - Simulatorスクリーンショットartifact

## 後続工程: 生成画像スキン

画像生成を使った猫の統一アセット、背景装飾、オンボーディング挿絵は、機能実装・実画面QA完了後にCodex等で行う。

詳細は [`future-generated-skin-production.md`](future-generated-skin-production.md) を正本とする。現在のコード描画Pixel Catは、生成アセット未導入時の完全なフォールバックとして維持する。
